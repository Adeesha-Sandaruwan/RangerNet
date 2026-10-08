import 'dart:convert';

import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../domain/patrol_records.dart';

enum PatrolPhotoSource { camera, gallery }

class PatrolPhotoPicker {
  PatrolPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const maxPhotos = 3;
  static const maxPhotoBytes = 100 * 1024;
  static const _uuid = Uuid();
  final ImagePicker _picker;

  Future<PatrolPhoto?> pick(PatrolPhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PatrolPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;
    final decoded = image.decodeImage(await file.readAsBytes());
    if (decoded == null) {
      throw const PatrolPhotoException('The selected image could not be read.');
    }
    for (final width in [1280, 1024, 800, 640, 480, 360]) {
      final resized = decoded.width > width
          ? image.copyResize(decoded, width: width)
          : decoded;
      for (final quality in [78, 68, 58, 48]) {
        final bytes = image.encodeJpg(resized, quality: quality);
        if (bytes.length <= maxPhotoBytes) {
          final safeName = file.name.replaceAll(
            RegExp(r'[^A-Za-z0-9._-]'),
            '_',
          );
          return PatrolPhoto(
            id: _uuid.v4(),
            fileName: safeName.isEmpty ? 'patrol-photo.jpg' : safeName,
            contentType: 'image/jpeg',
            base64Data: base64Encode(bytes),
            capturedAt: DateTime.now().toUtc(),
          );
        }
      }
    }
    throw const PatrolPhotoException(
      'This photo is too large after compression. Choose a smaller image.',
    );
  }
}

class PatrolPhotoException implements Exception {
  const PatrolPhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}
