#import "AudioProcessingAdapter.h"
#import <WebRTC/RTCAudioRenderer.h>
#import <os/lock.h>

@implementation AudioProcessingAdapter {
  NSMutableArray<id<RTCAudioRenderer>>* _renderers;
  NSMutableArray<id<ExternalAudioProcessingDelegate>>* _processors;
  os_unfair_lock _lock;
  size_t _currentSampleRate;
  size_t _currentChannels;
  BOOL _isAudioInitialized;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _lock = OS_UNFAIR_LOCK_INIT;
    _renderers = [[NSMutableArray<id<RTCAudioRenderer>> alloc] init];
    _processors = [[NSMutableArray<id<ExternalAudioProcessingDelegate>> alloc] init];
  }
  return self;
}
- (size_t)currentSampleRate {
  os_unfair_lock_lock(&_lock);
  size_t sampleRate = _currentSampleRate;
  os_unfair_lock_unlock(&_lock);
  return sampleRate;
}

- (size_t)currentChannels {
  os_unfair_lock_lock(&_lock);
  size_t channels = _currentChannels;
  os_unfair_lock_unlock(&_lock);
  return channels;
}
- (void)addProcessing:(id<ExternalAudioProcessingDelegate> _Nonnull)processor {
  os_unfair_lock_lock(&_lock);

  [_processors addObject:processor];

  if (_isAudioInitialized) {
    [processor audioProcessingInitializeWithSampleRate:_currentSampleRate
                                              channels:_currentChannels];
  }

  os_unfair_lock_unlock(&_lock);
}

- (void)removeProcessing:(id<ExternalAudioProcessingDelegate> _Nonnull)processor {
  os_unfair_lock_lock(&_lock);
  _processors = [[_processors
      filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject,
                                                                        NSDictionary* bindings) {
        return evaluatedObject != processor;
      }]] mutableCopy];
  os_unfair_lock_unlock(&_lock);
}

- (void)addAudioRenderer:(nonnull id<RTCAudioRenderer>)renderer {
  os_unfair_lock_lock(&_lock);
  [_renderers addObject:renderer];
  os_unfair_lock_unlock(&_lock);
}

- (void)removeAudioRenderer:(nonnull id<RTCAudioRenderer>)renderer {
  os_unfair_lock_lock(&_lock);
  _renderers = [[_renderers
      filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject,
                                                                        NSDictionary* bindings) {
        return evaluatedObject != renderer;
      }]] mutableCopy];
  os_unfair_lock_unlock(&_lock);
}

- (void)audioProcessingInitializeWithSampleRate:(size_t)sampleRateHz channels:(size_t)channels {
  os_unfair_lock_lock(&_lock);

  _currentSampleRate = sampleRateHz;
  _currentChannels = channels;
  _isAudioInitialized = YES;

  for (id<ExternalAudioProcessingDelegate> processor in _processors) {
    [processor audioProcessingInitializeWithSampleRate:sampleRateHz channels:channels];
  }

  os_unfair_lock_unlock(&_lock);
}

- (AVAudioPCMBuffer*)toPCMBuffer:(RTC_OBJC_TYPE(RTCAudioBuffer) *)audioBuffer {
  AVAudioFormat* format =
      [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                       sampleRate:audioBuffer.frames * 100.0
                                         channels:(AVAudioChannelCount)audioBuffer.channels
                                      interleaved:NO];
  AVAudioPCMBuffer* pcmBuffer =
      [[AVAudioPCMBuffer alloc] initWithPCMFormat:format
                                    frameCapacity:(AVAudioFrameCount)audioBuffer.frames];
  if (!pcmBuffer) {
    NSLog(@"Failed to create AVAudioPCMBuffer");
    return nil;
  }
  pcmBuffer.frameLength = (AVAudioFrameCount)audioBuffer.frames;
  for (int i = 0; i < audioBuffer.channels; i++) {
    float* sourceBuffer = [audioBuffer rawBufferForChannel:i];
    int16_t* targetBuffer = (int16_t*)pcmBuffer.int16ChannelData[i];
    for (int frame = 0; frame < audioBuffer.frames; frame++) {
      targetBuffer[frame] = sourceBuffer[frame];
    }
  }
  return pcmBuffer;
}

- (void)audioProcessingProcess:(RTC_OBJC_TYPE(RTCAudioBuffer) *)audioBuffer {
  os_unfair_lock_lock(&_lock);
  for (id<ExternalAudioProcessingDelegate> processor in _processors) {
    [processor audioProcessingProcess:audioBuffer];
  }

  for (id<RTCAudioRenderer> renderer in _renderers) {
    [renderer renderPCMBuffer:[self toPCMBuffer:audioBuffer]];
  }
  os_unfair_lock_unlock(&_lock);
}

- (void)audioProcessingRelease {
  os_unfair_lock_lock(&_lock);

  for (id<ExternalAudioProcessingDelegate> processor in _processors) {
    [processor audioProcessingRelease];
  }

  _isAudioInitialized = NO;
  _currentSampleRate = 0;
  _currentChannels = 0;

  os_unfair_lock_unlock(&_lock);
}

@end
