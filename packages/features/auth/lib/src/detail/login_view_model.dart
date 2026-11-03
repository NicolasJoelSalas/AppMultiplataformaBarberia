import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'login_ui_state.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required this.login,
    required this.register,
    required this.loginWithGoogle,
    required this.ensureProfile,
    required this.logout,
    required bool initiallyLoggedIn,
  }) : _state = LoginUiState(isLoading: initiallyLoggedIn);
  final LoginUseCase login;
  final RegisterUseCase register;
  final LoginWithGoogleUseCase loginWithGoogle;
  final EnsureClienteProfileUseCase ensureProfile;
  final LogoutUseCase logout;
  LoginUiState _state;
  LoginUiState get state => _state;
  bool _disposed = false;
  void _emit(LoginUiState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_state.isLoading) await _completeSession();
  }

  void onToggleRegistration() {
    if (_state.isLoading || _state.isAuthenticated) return;
    _emit(
      _state.copyWith(isRegistering: !_state.isRegistering, clearError: true),
    );
  }

  Future<void> onLogin(String email, String password) =>
      _authenticate(() => login(email, password));
  Future<void> onRegister(String email, String password, String confirmation) =>
      _authenticate(() => register(email, password, confirmation));
  Future<void> _authenticate(Future<AppResult<void>> Function() action) async {
    if (_state.isLoading || _state.isAuthenticated || _disposed) return;
    _emit(_state.copyWith(isLoading: true, clearError: true));
    try {
      final result = await action();
      if (result is Failure<void>) {
        _emit(_state.copyWith(isLoading: false, error: result.error));
      } else {
        await _completeSession();
      }
    } catch (_) {
      _emit(_state.copyWith(isLoading: false, error: AuthError.unknown));
    }
  }

  Future<void> onGoogleLogin(Future<String?> Function() getToken) async {
    if (_state.isLoading || _state.isAuthenticated || _disposed) return;
    _emit(_state.copyWith(isLoading: true, clearError: true));
    try {
      final token = await getToken();
      if (token == null) {
        _emit(_state.copyWith(isLoading: false));
        return;
      }
      final result = await loginWithGoogle(token);
      if (result is Failure<void>) {
        _emit(_state.copyWith(isLoading: false, error: result.error));
      } else {
        await _completeSession();
      }
    } catch (_) {
      _emit(_state.copyWith(isLoading: false, error: AuthError.googleOpen));
    }
  }

  Future<void> onRetryProfile() async {
    if (_state.isLoading || !_state.needsProfileRetry || _disposed) return;
    _emit(_state.copyWith(isLoading: true, clearError: true));
    await _completeSession();
  }

  Future<void> _completeSession() async {
    try {
      final result = await ensureProfile();
      if (result is Failure<void>) {
        _emit(
          _state.copyWith(
            isLoading: false,
            isAuthenticated: false,
            needsProfileRetry: true,
            error: result.error,
          ),
        );
      } else {
        _emit(
          _state.copyWith(
            isLoading: false,
            isAuthenticated: true,
            needsProfileRetry: false,
            clearError: true,
          ),
        );
      }
    } catch (_) {
      _emit(
        _state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          needsProfileRetry: true,
          error: AuthError.profileLoad,
        ),
      );
    }
  }

  Future<void> onLogout() async {
    if (_state.isLoading || !_state.isAuthenticated || _disposed) return;
    _emit(_state.copyWith(isLoading: true, clearError: true));
    try {
      final result = await logout();
      if (result is Failure<void>) {
        _emit(_state.copyWith(isLoading: false, error: result.error));
      } else {
        _emit(const LoginUiState());
      }
    } catch (_) {
      _emit(_state.copyWith(isLoading: false, error: AuthError.unknown));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
