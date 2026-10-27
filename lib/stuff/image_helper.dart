import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

/// Helper to pick an image that works on web and mobile.
/// Returns a map with either 'file' (File on mobile) or 'bytes' (Uint8List on web), and 'name'.
Future<Map<String, dynamic>?> pickImageForPlatform() async {
  final picker = ImagePicker();
  final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
  if (picked == null) return null;

  if (kIsWeb) {
    final bytes = await picked.readAsBytes();
    return {
      'bytes': bytes,
      'name': picked.name,
    };
  } else {
    final file = File(picked.path);
    return {
      'file': file,
      'path': picked.path,
      'name': picked.name,
    };
  }
}
