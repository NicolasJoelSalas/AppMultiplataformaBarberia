enum AuthError {
  requiredFields,
  invalidEmail,
  passwordLength,
  passwordConfirmation,
  emailExists,
  weakPassword,
  loginFailed,
  registerFailed,
  network,
  googleAccount,
  googleOpen,
  googleUnavailable,
  profileSignin,
  missingEmail,
  profileLoad,
  profilePermission,
  profileNameLength,
  profileSave,
  unknown,
}

sealed class AppResult<T> {
  const AppResult();
}

final class Success<T> extends AppResult<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends AppResult<T> {
  const Failure(this.error);
  final AuthError error;
}

abstract interface class AuthRepository {
  Future<AppResult<void>> login(String email, String password);
  Future<AppResult<void>> register(String email, String password);
  Future<AppResult<void>> loginWithGoogle(String idToken);
  bool get isLoggedIn;
  Future<AppResult<void>> logout();
}

abstract interface class SesionActual {
  String? get usuarioId;
}

abstract interface class ClienteRepository {
  Future<AppResult<void>> ensureCurrentProfile();
  Future<void> clearValidatedSession(String uid);
}
