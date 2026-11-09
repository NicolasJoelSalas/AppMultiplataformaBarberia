import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

class ServiciosViewModel extends ChangeNotifier {
  ServiciosViewModel(this._repository)
    : _saveService = SaveBarberService(_repository);

  final BarberServiceRepository _repository;
  final SaveBarberService _saveService;

  List<BarberService> _services = const [];
  ServiceFailure? _error;
  bool _loading = false;
  bool _saving = false;
  bool _disposed = false;

  List<BarberService> get services => _services;
  ServiceFailure? get error => _error;
  bool get loading => _loading;
  bool get saving => _saving;
  bool get busy => _loading || _saving;

  String newServiceId() => _repository.newServiceId();

  Future<void> load() async {
    if (busy || _disposed) return;
    _loading = true;
    _error = null;
    notifyListeners();
    await _reload();
    _loading = false;
    _notify();
  }

  Future<void> save({
    required String id,
    required bool create,
    required String name,
    required String price,
    required String duration,
  }) => _mutate(
    () => _saveService(
      id: id,
      create: create,
      name: name,
      price: price,
      duration: duration,
    ),
  );

  Future<void> toggleActive(BarberService service) async {
    if (busy || _disposed) return;
    try {
      await _mutate(() => _repository.setActive(service.id, !service.active));
    } on ServiceFailure catch (error) {
      _error = error;
      _notify();
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (busy || _disposed) throw ServiceFailure.operation;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      // A refresh failure is shown in the list. The write already succeeded.
      await _reload();
    } on ServiceFailure {
      rethrow;
    } catch (_) {
      throw ServiceFailure.operation;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<void> _reload() async {
    try {
      _services = List.unmodifiable(await _repository.loadOwnServices());
    } on ServiceFailure catch (error) {
      if (error == ServiceFailure.permission) _services = const [];
      _error = error;
    } catch (_) {
      _error = ServiceFailure.operation;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
