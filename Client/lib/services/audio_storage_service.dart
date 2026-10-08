import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'audio_converter_service.dart';

class StorageService {
  final AudioConverterService _converter = AudioConverterService();

  Future<String> uploadAudio(
    String filePath,
    String fileName,
  ) async {
    final supabase = Supabase.instance.client;

    // Convert the recorded M4A/MP4 file to a real WAV file
    final wavPath = await _converter.convertToWav(filePath);

    final wavFileName =
        '${fileName.replaceAll(RegExp(r'\.[^.]+$'), '')}.wav';

    final path = await supabase.storage
        .from('audio')
        .upload(
          wavFileName,
          File(wavPath),
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );

    print('✅ UPLOAD SUCCESS');
    print('📁 PATH: $path');

    final storagePath = path.startsWith('audio/')
        ? path.substring('audio/'.length)
        : path;

    print('🔗 Creating signed URL for: $storagePath');

    final signedUrl = await supabase.storage
        .from('audio')
        .createSignedUrl(
          storagePath,
          3600,
        );

    print('✅ SIGNED URL SUCCESS');

    return signedUrl;
  }
}