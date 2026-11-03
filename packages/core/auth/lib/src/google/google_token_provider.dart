import 'package:google_sign_in/google_sign_in.dart';

class GoogleTokenProvider {
  GoogleTokenProvider({this.serverClientId});
  final String? serverClientId;
  Future<void>? _initialization;
  Future<String?> call() async {
    final google = GoogleSignIn.instance;
    _initialization ??= google.initialize(serverClientId: serverClientId);
    await _initialization;
    try {
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw StateError('Missing Google ID token');
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}
