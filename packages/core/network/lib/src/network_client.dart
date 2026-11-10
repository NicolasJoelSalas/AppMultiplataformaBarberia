import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class NetworkClient {
  const NetworkClient();

  Future<Object?> getJson(Uri uri, {required Duration timeout}) =>
      _json(http.Request('GET', uri), timeout);

  Future<Object?> uploadJpeg(
    Uri uri,
    Uint8List bytes, {
    required Map<String, String> fields,
    required String filename,
    required Duration timeout,
  }) {
    final request = http.MultipartRequest('POST', uri)
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    return _json(request, timeout);
  }

  Future<Object?> _json(http.BaseRequest request, Duration timeout) async {
    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw http.ClientException(
          'Unexpected HTTP status ${response.statusCode}',
          request.url,
        );
      }
      return jsonDecode(response.body);
    } finally {
      client.close();
    }
  }

  Future<Uint8List?> download(
    Uri uri, {
    required int maxBytes,
    required Duration timeout,
  }) async {
    final client = http.Client();
    try {
      return await _readBytes(client, uri, maxBytes).timeout(timeout);
    } finally {
      client.close();
    }
  }

  Future<Uint8List?> _readBytes(
    http.Client client,
    Uri uri,
    int maxBytes,
  ) async {
    final response = await client.send(
      http.Request('GET', uri)..followRedirects = false,
    );
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > maxBytes) {
      return null;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxBytes) return null;
      bytes.add(chunk);
    }
    return bytes.isEmpty ? null : bytes.takeBytes();
  }
}
