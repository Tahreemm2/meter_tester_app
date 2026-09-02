// =============================================================================
// FILE: lib/core/services/media_capture_service.dart
// PURPOSE: Thin wrapper around package:image_picker so callers
// (InspectionBloc) get a base64 string ready to drop straight into the
// backend's images[].data_base64 field, instead of handling XFile/bytes
// plumbing themselves.
//
// WHY THIS EXISTS: backend/api/data.php requires 2-12 images per inspection
// submission, JPEG/PNG/WEBP, max 8 MB each (see MAX_IMAGE_BYTES in
// config/helpers.php). Images are downscaled client-side to keep uploads
// fast on field connections and comfortably under that limit.
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class CapturedPhoto {
  final String base64Data;
  final Uint8List bytes;
  const CapturedPhoto({required this.base64Data, required this.bytes});
}

class MediaCaptureService {
  MediaCaptureService._internal();
  static final MediaCaptureService instance = MediaCaptureService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Opens the camera or gallery per [source] and returns the picked image
  /// as base64. Returns null if the user cancelled — never throws for a
  /// simple cancel, but rethrows as a plain [Exception] with a
  /// user-presentable message for real failures (permission denial, etc.)
  /// so the caller can show it without knowing about image_picker types.
  Future<CapturedPhoto?> pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        // Downscale + compress so field uploads stay fast and comfortably
        // under the backend's 8 MB per-image limit.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return null; // user cancelled

      final bytes = await file.readAsBytes();
      return CapturedPhoto(base64Data: base64Encode(bytes), bytes: bytes);
    } catch (e) {
      throw Exception('Could not capture the photo. Please try again. ($e)');
    }
  }
}
