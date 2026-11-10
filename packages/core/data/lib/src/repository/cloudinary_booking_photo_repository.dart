import 'dart:math' as math;
import 'dart:typed_data' show ByteBuffer;
import 'dart:ui' as ui;

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:network/network.dart';

import 'cloudinary_reference.dart';

class CloudinaryBookingPhotoRepository implements BookingPhotoRepository {
  const CloudinaryBookingPhotoRepository(this.cloudName, this.uploadPreset);

  final String cloudName;
  final String uploadPreset;

  @override
  Future<String> upload(Uint8List bytes) async => (await _upload(bytes)).url;

  Future<CloudinaryPhoto> uploadPhoto(Uint8List bytes) =>
      _upload(bytes, requirePublicId: true);

  Future<CloudinaryPhoto> _upload(
    Uint8List bytes, {
    bool requirePublicId = false,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(cloudName) ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(uploadPreset)) {
      throw BookingFailure.photoUnavailable;
    }
    try {
      final jpeg = await _prepareJpeg(bytes);
      final data = await const NetworkClient().uploadJpeg(
        Uri.https('api.cloudinary.com', '/v1_1/$cloudName/image/upload'),
        jpeg,
        fields: {'upload_preset': uploadPreset},
        filename: 'referencia.jpg',
        timeout: const Duration(seconds: 30),
      );
      final url = data is Map ? data['secure_url'] : null;
      if (url is! String ||
          !url.startsWith(
            'https://res.cloudinary.com/$cloudName/image/upload/',
          ) ||
          !isCloudinaryReferenceUrl(url)) {
        throw BookingFailure.photoUpload;
      }
      final publicId = data is Map ? data['public_id'] : null;
      if (requirePublicId &&
          (publicId is! String || publicId.isEmpty || publicId.length > 300)) {
        throw BookingFailure.photoUpload;
      }
      return CloudinaryPhoto(url, publicId is String ? publicId : '');
    } catch (_) {
      throw BookingFailure.photoUpload;
    }
  }
}

class CloudinaryPhoto {
  const CloudinaryPhoto(this.url, this.publicId);
  final String url;
  final String publicId;
}

Future<Uint8List> _prepareJpeg(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final scale = math.min(
        1.0,
        1080 / math.max(descriptor.width, descriptor.height),
      );
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      try {
        final frame = (await codec.getNextFrame()).image;
        try {
          final pixels = await frame.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          );
          if (pixels == null) throw BookingFailure.photoUpload;
          return await compute(_encodeJpeg, (
            pixels.buffer,
            frame.width,
            frame.height,
          ));
        } finally {
          frame.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

Uint8List _encodeJpeg((ByteBuffer, int, int) input) {
  final (bytes, width, height) = input;
  return image.encodeJpg(
    image.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes,
      order: image.ChannelOrder.rgba,
    ),
    quality: 85,
  );
}
