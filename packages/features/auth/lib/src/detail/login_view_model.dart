import 'dart:async';

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
    this.googlePopup,
    String? initialUserId,
    this._sessionChanges,
    this._clearAccountCache,
  }) : _userId = initialUserId,
       _state = LoginUiState(isLoading: initiallyLoggedIn);
  final LoginUseCase login;
  final RegisterUseCase register;
  final LoginWithGoogleUseCase loginWithGoogle;
  final Future<AppResult<void>?> Function()? googlePopup;
  final EnsureClienteProfileUseCase ensureProfile;
  final LogoutUseCase logout;
  LoginUiState _state;
  LoginUiState get state => _state;
  final Stream<String?>? _sessionChanges;
  final Future<void> Function(String uid)? _clearAccountCache;
  Future<void> _cacheCleanup = Future.value();
  StreamSubscription<String?>? _sessionSubscription;
  String? _userId;
  int _sessionRevision = 0;
  int get sessionRevision => _sessionRevision;
  bool _disposed = false;

  bool _isCurrent(int revision) => !_disposed && revision == _sessionRevision;
  void _emit(LoginUiState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_disposed) return;
    _sessionSubscription ??= _sessionChanges?.listen(_onSessionChanged);
    if (_state.isLoading) await _completeSession();
  }

  void _onSessionChanged(String? userId) {
    if (_disposed || userId == _userId) return;
    final previous = _userId;
    _userId = userId;
    final revision = ++_sessionRevision;
    _emit(const LoginUiState(isLoading: true));
    unawaited(_switchAccount(previous, userId, revision));
  }

  Future<void> _switchAccount(
    String? previous,
    String? userId,
    int revision,
  ) async {
    final cleanup = _cacheCleanup.then((_) async {
      if (previous != null) await _clearAccountCache?.call(previous);
    });
    _cacheCleanup = cleanup.catchError((Object _) {});
    try {
      await cleanup;
    } catch (_) {
      if (_isCurrent(revision)) {
        _emit(const LoginUiState(error: AuthError.unknown));
      }
      return;
    }
    if (!_isCurrent(revision)) return;
    if (userId == null) {
      _emit(const LoginUiState());
    } else {
      await _completeSession();
    }
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
    final revision = _sessionRevision;
    _emit(_state.copyWith(isLoading: true, clearError: true));
    try {
      final result = await action();
      if (!_isCurrent(revision)) return;
      if (result is Failure<void>) {
        _emit(_state.copyWith(isLoading: false, error: result.error));
      } else if (_sessionChanges == null) {
        await _completeSession();
      }
    } catch (_) {
      if (!_isCurrent(revision)) return;
      _emit(_state.copyWith(isLoading: false, error: AuthError.unknown));
    }
  }

  Future<void> onGoogleLogin(Future<String?> Function() getToken) async {
    if (_state.isLoading || _state.isAuthenticated || _disposed) return;
    final revision = _sessionRevision;
    _emit(_state.copyWith(isLoading: true, clearError: true));
    try {
      final popup = googlePopup;
      final result = await (popup == null
          ? _googleWithToken(getToken, revision)
          : popup());
      if (!_isCurrent(revision)) return;
      if (result == null) {
        _emit(_state.copyWith(isLoading: false));
        return;
      }
      if (result is Failure<void>) {
        _emit(_state.copyWith(isLoading: false, error: result.error));
      } else if (_sessionChanges == null) {
        await _completeSession();
      }
    } catch (_) {
      if (!_isCurrent(revision)) return;
      _emit(_state.copyWith(isLoading: false, error: AuthError.googleOpen));
    }
  }

  Future<AppResult<void>?> _googleWithToken(
    Future<String?> Function() getToken,
    int revision,
  ) async {
    final token = await getToken();
    return token == null || !_isCurrent(revision)
        ? null
        : loginWithGoogle(token);
  }

  Future<void> onRetryProfile() async {
    if (_state.isLoading || !_state.needsProfileRetry || _disposed) return;
    _emit(_state.copyWith(isLoading: true, clearError: true));
    await _completeSession();
  }

  Future<void> _completeSession() async {
    final revision = _sessionRevision;
    try {
      final result = await ensureProfile();
      if (!_isCurrent(revision)) return;
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
      if (!_isCurrent(revision)) return;
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
    final revision = _sessionRevision;
    _emit(_state.copyWith(isLoading: true, clearError: true));
    try {
      final result = await logout();
      if (!_isCurrent(revision)) return;
      if (result is Failure<void>) {
        _emit(_state.copyWith(isLoading: false, error: result.error));
      } else {
        _emit(const LoginUiState());
      }
    } catch (_) {
      if (!_isCurrent(revision)) return;
      _emit(_state.copyWith(isLoading: false, error: AuthError.unknown));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }
}
