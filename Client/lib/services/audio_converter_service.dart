import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;

class AudioConverterService {
  Future<String> convertToWav(String inputPath) async {
    if (p.extension(inputPath).toLowerCase() == '.wav') {
      print('✅ FILE IS ALREADY WAV');
      print('🎵 WAV PATH: $inputPath');
      return inputPath;
    }

    final outputPath = p.join(
      p.dirname(inputPath),
      '${p.basenameWithoutExtension(inputPath)}_converted.wav',
    );

    final command =
        '-i "$inputPath" -ar 16000 -ac 1 -c:a pcm_s16le "$outputPath"';

    print('🎙️ INPUT PATH: $inputPath');
    print('🎵 OUTPUT PATH: $outputPath');
    print('⚙️ COMMAND: $command');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print('✅ AUDIO CONVERSION SUCCESS');
      print('🎵 WAV PATH: $outputPath');
      return outputPath;
    }

    throw Exception('Audio conversion failed');
  }
}