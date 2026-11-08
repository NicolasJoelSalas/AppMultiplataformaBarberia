import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

class MiCuentaViewModel extends ChangeNotifier {
  MiCuentaViewModel({required this.loadProfile, required this.updateName});

  final LoadProfileUseCase loadProfile;
  final UpdateProfileNameUseCase updateName;

  AccountProfile? profile;
  AuthError? error;
  bool loading = false;
  bool saving = false;
  bool _disposed = false;

  Future<void> load() async {
    if (loading || saving || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    final result = await _run(loadProfile.call, AuthError.profileLoad);
    if (_disposed) return;
    loading = false;
    _apply(result);
    notifyListeners();
  }

  Future<bool> save(String name) async {
    if (saving || loading || _disposed || profile == null) return false;
    saving = true;
    error = null;
    notifyListeners();
    final result = await _run(() => updateName(name), AuthError.profileSave);
    if (_disposed) return false;
    saving = false;
    _apply(result);
    notifyListeners();
    return result is Success<AccountProfile>;
  }

  Future<AppResult<AccountProfile>> _run(
    Future<AppResult<AccountProfile>> Function() action,
    AuthError fallback,
  ) async {
    try {
      return await action();
    } catch (_) {
      return Failure(fallback);
    }
  }

  void _apply(AppResult<AccountProfile> result) {
    switch (result) {
      case Success(:final value):
        profile = value;
      case Failure(error: final reason):
        error = reason;
    }
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
