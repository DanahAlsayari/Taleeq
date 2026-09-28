import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RecordingService {
  final recorder = AudioRecorder();

  Future<bool> startRecording(String fileName) async {
    try {
      if (await recorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();

        final path = p.join(
          directory.path,
          "$fileName.wav",
        );

        final config = RecordConfig(
          encoder: AudioEncoder.wav,
        );

        await recorder.start(
          config,
          path: path,
        );

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

  void disposeRecord() async {
    await recorder.dispose();
  }
}