import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:io';

class StorageService {
  Future<String> uploadAudio(String filePath, String fileName) async {
    final recordFile = File(filePath);
    final supabase = Supabase.instance.client;
    final path = await supabase.storage
        .from('audio')
        .upload(
          fileName,
          recordFile,
          fileOptions: const FileOptions(upsert: true),
        );

    return path;
  }
}
