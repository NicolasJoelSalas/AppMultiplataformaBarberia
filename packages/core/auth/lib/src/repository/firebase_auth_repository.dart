import 'package:domain/domain.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthRepository implements AuthRepository, SesionActual {
  FirebaseAuthRepository(this.auth);
  final FirebaseAuth auth;
  @override
  bool get isLoggedIn => auth.currentUser != null;
  @override
  String? get usuarioId => auth.currentUser?.uid;

  Stream<String?> get sessionChanges =>
      auth.authStateChanges().map((user) => user?.uid).distinct();
  @override
  Future<AppResult<void>> login(String email, String password) =>
      _execute(() async {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }, AuthError.loginFailed);
  @override
  Future<AppResult<void>> register(String email, String password) =>
      _execute(() async {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }, AuthError.registerFailed);
  @override
  Future<AppResult<void>> loginWithGoogle(String token) => _execute(() async {
    await auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
  }, AuthError.googleAccount);
  Future<AppResult<void>?> loginWithGooglePopup() async {
    try {
      await auth.signInWithPopup(GoogleAuthProvider());
      return const Success(null);
    } on FirebaseAuthException catch (error) {
      return switch (error.code) {
        'popup-closed-by-user' || 'cancelled-popup-request' => null,
        'network-request-failed' => const Failure(AuthError.network),
        _ => const Failure(AuthError.googleOpen),
      };
    }
  }

  @override
  Future<AppResult<void>> logout() => _execute(auth.signOut, AuthError.unknown);
  Future<AppResult<void>> _execute(
    Future<void> Function() action,
    AuthError fallback,
  ) async {
    try {
      await action();
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(switch (e.code) {
        'network-request-failed' => AuthError.network,
        'email-already-in-use' => AuthError.emailExists,
        'weak-password' => AuthError.weakPassword,
        'invalid-email' => AuthError.invalidEmail,
        _ => fallback,
      });
    } catch (_) {
      return Failure(fallback);
    }
  }
}
