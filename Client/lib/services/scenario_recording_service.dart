
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ScenarioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  String? _recordingPath;

  Future<bool> get isRecording async => await _recorder.isRecording();

  String? get recordingPath => _recordingPath;

  // Start recording the user's microphone
  Future<void> startRecording() async {
    if (await _recorder.isRecording()) {
      throw Exception('Recording is already in progress.');
    }

    final hasPermission = await _recorder.hasPermission();

    if (!hasPermission) {
      throw Exception('Microphone permission was not granted.');
    }

    final directory = await getTemporaryDirectory();

    final fileName =
        'scenario_${DateTime.now().millisecondsSinceEpoch}.wav';

    _recordingPath = '${directory.path}/$fileName';

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
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    await _recorder.dispose();
  }
}
