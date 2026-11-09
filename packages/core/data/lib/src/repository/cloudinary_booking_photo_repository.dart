import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data' show ByteBuffer;
import 'dart:ui' as ui;

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as image;

class CloudinaryBookingPhotoRepository implements BookingPhotoRepository {
  const CloudinaryBookingPhotoRepository(this.cloudName, this.uploadPreset);

  final String cloudName;
  final String uploadPreset;

  @override
  Future<String> upload(Uint8List bytes) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(cloudName) ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(uploadPreset)) {
      throw BookingFailure.photoUnavailable;
    }
    final client = http.Client();
    try {
      final jpeg = await _prepareJpeg(bytes);
      final request =
          http.MultipartRequest(
              'POST',
              Uri.https('api.cloudinary.com', '/v1_1/$cloudName/image/upload'),
            )
            ..fields['upload_preset'] = uploadPreset
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                jpeg,
                filename: 'referencia.jpg',
                contentType: MediaType('image', 'jpeg'),
              ),
            );
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw BookingFailure.photoUpload;
      final data = jsonDecode(response.body);
      final url = data is Map ? data['secure_url'] : null;
      if (url is! String ||
          !url.startsWith(
            'https://res.cloudinary.com/$cloudName/image/upload/',
          ) ||
          !isBookingReferenceUrl(url)) {
        throw BookingFailure.photoUpload;
      }
      return url;
    } catch (_) {
      throw BookingFailure.photoUpload;
    } finally {
      client.close();
    }
  }
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
