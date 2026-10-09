// Takes a photo from the camera/gallery and shrinks it for offline upload.
import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/incident_report.dart';

// Where the ranger wants to choose a photo from.
enum EvidenceSource { camera, gallery }

/// Picks, compresses, and encodes one incident photo.
class IncidentEvidencePicker {
  IncidentEvidencePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const maxEvidenceCount = 3;
  static const maxImageBytes = 100 * 1024;
  static const _uuid = Uuid();
  final ImagePicker _picker;

  // Return null if the user cancels; otherwise return a small JPEG photo.
  Future<IncidentEvidence?> pick(EvidenceSource source) async {
    final file = await _picker.pickImage(
      source: source == EvidenceSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;

    final originalBytes = await file.readAsBytes();
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw const IncidentEvidenceException(
        'This image could not be read. Choose another photo.',
      );
    }

    // Try smaller sizes and lower quality until the photo fits the size limit.
    for (final width in [1280, 1024, 800, 640, 480, 360]) {
      final resized = decoded.width > width
          ? img.copyResize(decoded, width: width)
          : decoded;
      for (final quality in [78, 68, 58, 48]) {
        final compressed = img.encodeJpg(resized, quality: quality);
        if (compressed.length <= maxImageBytes) {
          final safeName = file.name.replaceAll(
            RegExp(r'[^A-Za-z0-9._-]'),
            '_',
          );
          return IncidentEvidence(
            id: _uuid.v4(),
            fileName: safeName.isEmpty ? 'evidence.jpg' : safeName,
            base64Data: base64Encode(compressed),
            contentType: 'image/jpeg',
          );
        }
      }
    }

    throw const IncidentEvidenceException(
      'This photo is still too large after compression. Try a smaller image.',
    );
  }
}

/// A photo problem that the screen can explain to the ranger.
class IncidentEvidenceException implements Exception {
  const IncidentEvidenceException(this.message);
  final String message;

  @override
  String toString() => message;
}
