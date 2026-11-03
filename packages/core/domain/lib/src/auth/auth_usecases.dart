import 'auth_contracts.dart';

class LoginUseCase {
  const LoginUseCase(this.repository);
  final AuthRepository repository;
  Future<AppResult<void>> call(String email, String password) {
    final clean = email.trim();
    if (clean.isEmpty || password.trim().isEmpty) {
      return Future.value(const Failure(AuthError.requiredFields));
    }
    return repository.login(clean, password);
  }
}

class RegisterUseCase {
  const RegisterUseCase(this.repository);
  final AuthRepository repository;
  Future<AppResult<void>> call(
    String email,
    String password,
    String confirmation,
  ) {
    final clean = email.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(clean)) {
      return Future.value(const Failure(AuthError.invalidEmail));
    }
    if (password.trim().isEmpty || password.length < 6) {
      return Future.value(const Failure(AuthError.passwordLength));
    }
    if (password != confirmation) {
      return Future.value(const Failure(AuthError.passwordConfirmation));
    }
    return repository.register(clean, password);
  }
}

class LoginWithGoogleUseCase {
  const LoginWithGoogleUseCase(this.repository);
  final AuthRepository repository;
  Future<AppResult<void>> call(String token) => token.trim().isEmpty
      ? Future.value(const Failure(AuthError.googleAccount))
      : repository.loginWithGoogle(token);
}

class EnsureClienteProfileUseCase {
  const EnsureClienteProfileUseCase(this.repository);
  final ClienteRepository repository;
  Future<AppResult<void>> call() => repository.ensureCurrentProfile();
}

class LogoutUseCase {
  const LogoutUseCase(this.auth, this.sesion, this.clientes);
  final AuthRepository auth;
  final SesionActual sesion;
  final ClienteRepository clientes;
  Future<AppResult<void>> call() async {
    final uid = sesion.usuarioId;
    if (uid != null) await clientes.clearValidatedSession(uid);
    return auth.logout();
  }
}
