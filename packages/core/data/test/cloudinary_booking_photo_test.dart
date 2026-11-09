import 'package:core_data/core_data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'uploads a size-limited JPEG and validates the Cloudinary URL',
    () async {
      const repo = CloudinaryBookingPhotoRepository('demo', 'booking-test');
      final original = image.encodePng(image.Image(width: 1200, height: 600));
      const url = 'https://res.cloudinary.com/demo/image/upload/photo.jpg';
      final uploaded = await http.runWithClient(
        () => repo.upload(original),
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url,
            Uri.parse('https://api.cloudinary.com/v1_1/demo/image/upload'),
          );
          final multipart = String.fromCharCodes(request.bodyBytes);
          expect(multipart, contains('booking-test'));
          expect(multipart, contains('image/jpeg'));
          final bytes = request.bodyBytes;
          final start = Iterable<int>.generate(bytes.length - 1)
              .firstWhere((i) => bytes[i] == 0xff && bytes[i + 1] == 0xd8);
          final jpeg = image.decodeJpg(bytes.sublist(start));
          expect(jpeg?.width, 1080);
          expect(jpeg?.height, 540);
          return http.Response('{"secure_url":"$url"}', 200);
        }),
      );
      expect(uploaded, url);
    },
  );

  test('configuration and unrelated upload URLs fail safely', () async {
    final original = image.encodePng(image.Image(width: 4, height: 4));
    await expectLater(
      const CloudinaryBookingPhotoRepository('', '').upload(original),
      throwsA(BookingFailure.photoUnavailable),
    );
    await expectLater(
      http.runWithClient(
        () => const CloudinaryBookingPhotoRepository(
          'demo',
          'booking-test',
        ).upload(original),
        () => MockClient(
          (_) async => http.Response(
            '{"secure_url":"https://res.cloudinary.com/another/image/upload/photo.jpg"}',
            200,
          ),
        ),
      ),
      throwsA(BookingFailure.photoUpload),
    );
  });
}
