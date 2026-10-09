import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

import 'dart:async';

class RecordingService {
  static const int minRecordingSeconds = 15;
  static const int maxRecordingSeconds = 300;

  final recorder = AudioRecorder();
  final player = AudioPlayer();
  Timer? recordingTimer;
  int recordingSeconds = 0;

  Timer? amplitudeTimer;
  final List<double> amplitudes = [];

  Future<bool> startRecording(String fileName) async {
    try {
      if (await recorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();

        final path = p.join(directory.path, "$fileName.wav");

        final config = RecordConfig(encoder: AudioEncoder.wav);

        await recorder.start(config, path: path);

        return true;
      }
    } catch (e) {
      print("Start Recording error: $e");
    }

    return false;
  }

  Future<String?> stopRecording() async {
    try {
      final recordPath = await recorder.stop();

      if (recordPath != null) {
        return recordPath;
      }
    } catch (e) {
      print("Stop Recording error: $e");
    }

    return null;
  }

  Future<Amplitude> getAmplitude() async {
    return await recorder.getAmplitude();
  }

  Future<void> pauseAudio() async {
    await player.pause();
  }

  Future<void> stopAudio() async {
    await player.stop();
  }

  Future<void> resumeAudio() async {
    await player.play();
  }

  Future<void> loadAudio(String path) async {
    await player.setFilePath(path);
  }

  void startRecordingTimer(
    void Function(int) onTick,
    void Function() onMaxDuration,
  ) {
    recordingTimer?.cancel();
    recordingSeconds = 0;

    recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      recordingSeconds++;
      onTick(recordingSeconds);

      if (recordingSeconds >= maxRecordingSeconds) {
        timer.cancel();
        recordingTimer = null;
        onMaxDuration();
      }
    });
  }

  void stopRecordingTimer() {
    recordingTimer?.cancel();
    recordingTimer = null;
  }

  void startAmplitudeTimer(void Function(List<double>) onUpdate) {
    amplitudeTimer?.cancel();
    amplitudes.clear();

    amplitudeTimer = Timer.periodic(const Duration(milliseconds: 150), (
      timer,
    ) async {
      try {
        final amplitude = await getAmplitude();

        if (!timer.isActive) return;

        amplitudes.add(amplitude.current);

        if (amplitudes.length > 35) {
          amplitudes.removeAt(0);
        }

        onUpdate(List<double>.from(amplitudes));
      } catch (e) {
        print("Amplitude error: $e");
      }
    });
  }

  void stopAmplitudeTimer() {
    amplitudeTimer?.cancel();
    amplitudeTimer = null;
  }

  bool isRecordingDurationValid(int seconds) {
    return seconds >= minRecordingSeconds;
  }

  Future<void> disposeRecord() async {
    stopAmplitudeTimer();
    stopRecordingTimer();

    if (await recorder.isRecording()) {
      await recorder.stop();
    }

    await player.dispose();
    await recorder.dispose();
  }
}
