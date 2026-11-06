
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ScenarioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  String? _recordingPath;
  bool _nativeRecording = false;

  bool get _useNativeRecorder => Platform.isIOS;

  Future<bool> get isRecording async {
    if (_nativeRecording) return true;
    return await _recorder.isRecording();
  }

  String? get recordingPath => _recordingPath;

  // Start recording
  Future<void> startRecording() async {
    if (await isRecording) {
      throw Exception('Recording is already in progress.');
    }

    final directory = await getTemporaryDirectory();

    final fileName =
        'scenario_${DateTime.now().millisecondsSinceEpoch}.wav';

    _recordingPath = '${directory.path}/$fileName';

    if (_useNativeRecorder) {
      _recordingPath =
          await NativeAudioManagement.startNativeRecording(
        _recordingPath!,
      );

      _nativeRecording = true;
      return;
    }

    final hasPermission = await _recorder.hasPermission();

    if (!hasPermission) {
      throw Exception('Microphone permission was not granted.');
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );
  }

  // Stop recording and return the audio file path
  Future<String?> stopRecording() async {
    if (_nativeRecording) {
      final path = await NativeAudioManagement.stopNativeRecording();

      _nativeRecording = false;
      _recordingPath = path;

      return path;
    }

    if (!await _recorder.isRecording()) {
      return _recordingPath;
    }

    final path = await _recorder.stop();

    _recordingPath = path ?? _recordingPath;

    return _recordingPath;
  }

  // Delete the temporary recording
  Future<void> deleteRecording() async {
    final path = _recordingPath;

    if (path == null) return;

    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }

    _recordingPath = null;
  }

  // Release recorder resources
  Future<void> dispose() async {
    if (_nativeRecording) {
      await stopRecording();
    } else if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    await _recorder.dispose();
  }
}
