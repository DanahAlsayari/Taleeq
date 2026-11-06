#import "AudioRecorder.h"

#import <AVFoundation/AVFoundation.h>
#import <os/lock.h>
#import <stdatomic.h>
#import <stdint.h>
#import <stdlib.h>
#import <math.h>
#import <string.h>
@implementation AudioRecorder {
  // Audio format
  size_t _sampleRate;
  size_t _channels;
  BOOL _audioInitialized;
  atomic_int _currentAmplitudeMilliDb;
  // Recording state
  BOOL _recording;
  atomic_bool _recordingAtomic;
  NSString *_filePath;

  // Audio buffer
  int16_t *_ringBuffer;
  size_t _ringBufferCapacity;

  atomic_size_t _writeIndex;
  atomic_size_t _readIndex;

  // WAV writer
  NSFileHandle *_fileHandle;
  dispatch_queue_t _writerQueue;
  dispatch_source_t _writerTimer;

  uint64_t _totalFramesWritten;
  uint64_t _droppedSamples;

  os_unfair_lock _stateLock;
}
- (instancetype)init {
  self = [super init];

  if (self) {
    _stateLock = OS_UNFAIR_LOCK_INIT;

    _sampleRate = 0;
    _channels = 0;
    _audioInitialized = NO;

    _recording = NO;
    atomic_init(&_recordingAtomic, false);
    _filePath = nil;

    _ringBuffer = NULL;
    _ringBufferCapacity = 0;

    atomic_init(&_writeIndex, 0);
    atomic_init(&_readIndex, 0);

    _fileHandle = nil;
    _writerQueue = dispatch_queue_create(
        "com.taleeq.audio-recorder.writer",
        DISPATCH_QUEUE_SERIAL
    );

    _writerTimer = nil;

    _totalFramesWritten = 0;
    _droppedSamples = 0;
  }
    atomic_init(&_currentAmplitudeMilliDb, -160000);
  return self;
}

- (BOOL)isRecording {
  os_unfair_lock_lock(&_stateLock);
  BOOL recording = _recording;
  os_unfair_lock_unlock(&_stateLock);

  return recording;
}
- (void)audioProcessingInitializeWithSampleRate:(size_t)sampleRateHz
                                       channels:(size_t)channels {
  os_unfair_lock_lock(&_stateLock);

  free(_ringBuffer);
  _ringBuffer = NULL;
  _ringBufferCapacity = 0;

  _sampleRate = sampleRateHz;
  _channels = channels;

  if (sampleRateHz > 0 && channels > 0 &&
      sampleRateHz <= SIZE_MAX / channels / 2) {

    // Allocate 2 seconds of audio samples.
    _ringBufferCapacity = sampleRateHz * channels * 2;

    _ringBuffer = calloc(_ringBufferCapacity, sizeof(int16_t));

    _audioInitialized = (_ringBuffer != NULL);

    atomic_store(&_writeIndex, 0);
    atomic_store(&_readIndex, 0);

  } else {
    _audioInitialized = NO;
  }

  os_unfair_lock_unlock(&_stateLock);

  NSLog(@"[AudioRecorder] Initialized: %zu Hz, %zu channels, buffer: %s",
        sampleRateHz, channels,
        _audioInitialized ? "ready" : "failed");
}
- (void)audioProcessingProcess:(RTC_OBJC_TYPE(RTCAudioBuffer) *)audioBuffer {
  if (!atomic_load_explicit(&_recordingAtomic, memory_order_relaxed)) {
    return;
  }

  if (_ringBuffer == NULL || _ringBufferCapacity == 0) {
    return;
  }

  size_t frames = audioBuffer.frames;
  size_t channels = audioBuffer.channels;
  size_t sampleCount = frames * channels;

  if (channels != _channels || sampleCount > _ringBufferCapacity) {
    _droppedSamples += sampleCount;
    return;
  }

  size_t writeIndex = atomic_load_explicit(&_writeIndex, memory_order_relaxed);
  size_t readIndex = atomic_load_explicit(&_readIndex, memory_order_acquire);

  size_t available = _ringBufferCapacity - (writeIndex - readIndex);

  // Drop the complete audio block if the buffer is full.
  if (sampleCount > available) {
    _droppedSamples += sampleCount;
    return;
  }

  // Convert planar float audio into interleaved PCM16.
  for (size_t frame = 0; frame < frames; frame++) {
    for (size_t channel = 0; channel < channels; channel++) {
      float *source = [audioBuffer rawBufferForChannel:(int)channel];
      float sample = source[frame];

      if (sample > 1.0f) sample = 1.0f;
      if (sample < -1.0f) sample = -1.0f;

      int16_t pcmSample = (int16_t)lrintf(sample * 32767.0f);

      size_t index = (writeIndex + frame * channels + channel)
                     % _ringBufferCapacity;

      _ringBuffer[index] = pcmSample;
    }
  }

  atomic_store_explicit(
      &_writeIndex,
      writeIndex + sampleCount,
      memory_order_release
  );
    double sumSquares = 0.0;

for (size_t i = 0; i < sampleCount; i++) {
  double sample = (double)_ringBuffer[
      (writeIndex + i) % _ringBufferCapacity] / 32768.0;
  sumSquares += sample * sample;
}

double rms = sqrt(sumSquares / (double)sampleCount);
double db = rms > 0.0 ? 20.0 * log10(rms) : -160.0;

if (db < -160.0) db = -160.0;
if (db > 0.0) db = 0.0;

atomic_store_explicit(
    &_currentAmplitudeMilliDb,
    (int)(db * 1000.0),
    memory_order_relaxed
);
}
- (void)audioProcessingRelease {
  [self stopRecording];

  os_unfair_lock_lock(&_stateLock);

  _audioInitialized = NO;
  _sampleRate = 0;
  _channels = 0;

  os_unfair_lock_unlock(&_stateLock);

  NSLog(@"[AudioRecorder] Audio processing released");
}
- (NSData *)wavHeaderWithDataSize:(uint32_t)dataSize {
  uint8_t header[44] = {0};

  uint32_t byteRate = (uint32_t)(_sampleRate * _channels * 2);
  uint16_t blockAlign = (uint16_t)(_channels * 2);

  // RIFF header
  memcpy(header, "RIFF", 4);
  uint32_t fileSize = dataSize + 36;
  memcpy(header + 4, &fileSize, 4);
  memcpy(header + 8, "WAVE", 4);

  // fmt chunk
  memcpy(header + 12, "fmt ", 4);
  uint32_t subchunkSize = 16;
  memcpy(header + 16, &subchunkSize, 4);

  uint16_t audioFormat = 1; // PCM
  memcpy(header + 20, &audioFormat, 2);

  uint16_t channels = (uint16_t)_channels;
  memcpy(header + 22, &channels, 2);

  uint32_t sampleRate = (uint32_t)_sampleRate;
  memcpy(header + 24, &sampleRate, 4);
  memcpy(header + 28, &byteRate, 4);

  memcpy(header + 32, &blockAlign, 2);

  uint16_t bitsPerSample = 16;
  memcpy(header + 34, &bitsPerSample, 2);

  // data chunk
  memcpy(header + 36, "data", 4);
  memcpy(header + 40, &dataSize, 4);

  return [NSData dataWithBytes:header length:44];
}
- (void)drainRingBuffer {
  if (_fileHandle == nil || _ringBuffer == NULL) {
    return;
  }

  size_t readIndex = atomic_load_explicit(
      &_readIndex, memory_order_relaxed);

  size_t writeIndex = atomic_load_explicit(
      &_writeIndex, memory_order_acquire);

  size_t available = writeIndex - readIndex;

  if (available == 0) {
    return;
  }

  size_t firstChunk = MIN(
      available,
      _ringBufferCapacity - (readIndex % _ringBufferCapacity)
  );

  NSData *firstData = [NSData dataWithBytes:
      &_ringBuffer[readIndex % _ringBufferCapacity]
                                      length:firstChunk * sizeof(int16_t)];

  [_fileHandle writeData:firstData];

  size_t remaining = available - firstChunk;

  if (remaining > 0) {
    NSData *secondData = [NSData dataWithBytes:
        _ringBuffer
                                        length:remaining * sizeof(int16_t)];

    [_fileHandle writeData:secondData];
  }

  atomic_store_explicit(
      &_readIndex,
      readIndex + available,
      memory_order_release
  );

  _totalFramesWritten += available / _channels;
}
- (void)startWriterTimer {
  if (_writerTimer != nil) {
    return;
  }

  _writerTimer = dispatch_source_create(
      DISPATCH_SOURCE_TYPE_TIMER,
      0,
      0,
      _writerQueue
  );

  __weak typeof(self) weakSelf = self;

  dispatch_source_set_event_handler(_writerTimer, ^{
    [weakSelf drainRingBuffer];
  });

  dispatch_source_set_timer(
      _writerTimer,
      dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC),
      20 * NSEC_PER_MSEC,
      2 * NSEC_PER_MSEC
  );

  dispatch_resume(_writerTimer);
}
- (BOOL)startRecordingToPath:(NSString *)path
                       error:(NSError **)error {
  os_unfair_lock_lock(&_stateLock);

  if (_recording || !_audioInitialized ||
      _ringBuffer == NULL || _sampleRate == 0 || _channels == 0) {
    os_unfair_lock_unlock(&_stateLock);

    if (error) {
      *error = [NSError errorWithDomain:@"AudioRecorder"
                                   code:1
                               userInfo:@{
        NSLocalizedDescriptionKey:
            @"Audio is not initialized or recording is already active."
      }];
    }
    return NO;
  }

  if (path.length == 0 ||
      _sampleRate > UINT32_MAX / _channels / 2 ||
      _channels > UINT16_MAX / 2) {
    os_unfair_lock_unlock(&_stateLock);

    if (error) {
      *error = [NSError errorWithDomain:@"AudioRecorder"
                                   code:2
                               userInfo:@{
        NSLocalizedDescriptionKey: @"Invalid recording path or audio format."
      }];
    }
    return NO;
  }

  NSError *fileError = nil;
  [[NSFileManager defaultManager] createFileAtPath:path
                                          contents:nil
                                        attributes:nil];

  NSFileHandle *fileHandle =
      [NSFileHandle fileHandleForWritingAtPath:path];

  if (fileHandle == nil) {
    os_unfair_lock_unlock(&_stateLock);

    if (error) {
      *error = [NSError errorWithDomain:@"AudioRecorder"
                                   code:3
                               userInfo:@{
        NSLocalizedDescriptionKey:
            @"Could not create the recording file."
      }];
    }
    return NO;
  }

  _fileHandle = fileHandle;
  _filePath = [path copy];

  NSData *header = [self wavHeaderWithDataSize:0];

  @try {
    [_fileHandle writeData:header];
  } @catch (NSException *exception) {
    [_fileHandle closeFile];
    _fileHandle = nil;
    _filePath = nil;
    os_unfair_lock_unlock(&_stateLock);

    if (error) {
      *error = [NSError errorWithDomain:@"AudioRecorder"
                                   code:4
                               userInfo:@{
        NSLocalizedDescriptionKey: exception.reason ?: @"WAV header write failed."
      }];
    }
    return NO;
  }

  atomic_store(&_writeIndex, 0);
  atomic_store(&_readIndex, 0);

  _totalFramesWritten = 0;
  _droppedSamples = 0;

  _recording = YES;
  atomic_store_explicit(&_recordingAtomic, true, memory_order_release);


  os_unfair_lock_unlock(&_stateLock);
  [self startWriterTimer];
  NSLog(@"[AudioRecorder] Recording started: %@", path);
  return YES;
}
- (void)stopWriterTimer {
  dispatch_sync(_writerQueue, ^{
    if (self->_writerTimer != nil) {
      dispatch_source_cancel(self->_writerTimer);
      self->_writerTimer = nil;
    }

    [self drainRingBuffer];
  });
}
- (nullable NSString *)stopRecording {
  os_unfair_lock_lock(&_stateLock);

  if (!_recording) {
    os_unfair_lock_unlock(&_stateLock);
    return nil;
  }

  _recording = NO;
  atomic_store_explicit(
      &_recordingAtomic,
      false,
      memory_order_release
  );

  NSString *recordedPath = [_filePath copy];

  os_unfair_lock_unlock(&_stateLock);

  // Stop the timer and flush remaining audio samples.
  [self stopWriterTimer];

  os_unfair_lock_lock(&_stateLock);

  if (_fileHandle == nil || _channels == 0) {
    os_unfair_lock_unlock(&_stateLock);
    return nil;
  }

  uint64_t dataSize64 =
      _totalFramesWritten * _channels * sizeof(int16_t);

  if (dataSize64 > UINT32_MAX) {
    NSLog(@"[AudioRecorder] WAV file is too large.");
    [_fileHandle closeFile];
    _fileHandle = nil;
    _filePath = nil;
    os_unfair_lock_unlock(&_stateLock);
    return nil;
  }

  NSData *header = [self wavHeaderWithDataSize:(uint32_t)dataSize64];

  @try {
    [_fileHandle seekToFileOffset:0];
    [_fileHandle writeData:header];
    [_fileHandle synchronizeFile];
    [_fileHandle closeFile];
  } @catch (NSException *exception) {
    NSLog(@"[AudioRecorder] Failed to finalize WAV: %@",
          exception.reason);
    [_fileHandle closeFile];
    _fileHandle = nil;
    _filePath = nil;
    os_unfair_lock_unlock(&_stateLock);
    return nil;
  }

  _fileHandle = nil;
  _filePath = nil;

  os_unfair_lock_unlock(&_stateLock);

  NSLog(@"[AudioRecorder] Recording stopped: %@", recordedPath);

  return recordedPath;
}
- (double)currentAmplitude {
  return (double)atomic_load_explicit(
      &_currentAmplitudeMilliDb,
      memory_order_relaxed
  ) / 1000.0;
}
@end