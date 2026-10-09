import 'dart:convert';

import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../domain/patrol_records.dart';

/// Selects the device source used to capture or choose patrol evidence.
enum PatrolPhotoSource { camera, gallery }

/// Adapts image-picker input into compressed, Base64 patrol-photo records. SRP: handles photo acquisition and encoding only.
class PatrolPhotoPicker {
  /// Creates a picker with an injectable platform plugin.
  PatrolPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Maximum-count hint for consumers that enforce a patrol photo limit.
  static const maxPhotos = 3;

  /// Maximum compressed payload size for one stored photo.
  static const maxPhotoBytes = 100 * 1024;

  /// ID generator used to assign each captured photo a stable identifier.
  static const _uuid = Uuid();

  /// Platform image source used to capture or select photos.
  final ImagePicker _picker;

  /// Captures or selects an image, returning null when selection is cancelled.
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
    // Try progressively smaller dimensions and JPEG qualities until the payload fits.
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

/// Describes a photo-selection or compression failure.
class PatrolPhotoException implements Exception {
  /// Creates an exception with a user-presentable explanation.
  const PatrolPhotoException(this.message);

  /// User-presentable explanation of the photo failure.
  final String message;

  @override
  String toString() => message;
}
