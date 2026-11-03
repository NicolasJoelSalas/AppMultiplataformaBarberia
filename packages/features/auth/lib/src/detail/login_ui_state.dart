import 'package:domain/domain.dart';

class LoginUiState {
  const LoginUiState({
    this.isLoading = false,
    this.isRegistering = false,
    this.isAuthenticated = false,
    this.needsProfileRetry = false,
    this.error,
  });
  final bool isLoading, isRegistering, isAuthenticated, needsProfileRetry;
  final AuthError? error;
  LoginUiState copyWith({
    bool? isLoading,
    bool? isRegistering,
    bool? isAuthenticated,
    bool? needsProfileRetry,
    AuthError? error,
    bool clearError = false,
  }) => LoginUiState(
    isLoading: isLoading ?? this.isLoading,
    isRegistering: isRegistering ?? this.isRegistering,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    needsProfileRetry: needsProfileRetry ?? this.needsProfileRetry,
    error: clearError ? null : error ?? this.error,
  );
}
