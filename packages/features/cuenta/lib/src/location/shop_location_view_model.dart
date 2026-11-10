import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

enum LocationFailure { load, gps, save, route }

class ShopLocationViewModel extends ChangeNotifier {
  ShopLocationViewModel(
    this.locations,
    this.device, {
    this.barberId,
    this.routes,
  });

  final ShopLocationRepository locations;
  final DeviceLocationRepository device;
  final String? barberId;
  final ShopRouteRepository? routes;

  MapPoint? destination;
  MapPoint? selected;
  ShopRoute? route;
  LocationFailure? failure;
  bool busy = false;
  bool loaded = false;
  bool _disposed = false;

  bool get editing => barberId == null;

  Future<void> load() => _run(LocationFailure.load, () async {
    destination = await locations.read(barberId: barberId);
    selected = editing ? destination : null;
    loaded = true;
  });

  void select(MapPoint point) {
    if (busy || !point.isValid) return;
    selected = point;
    route = null;
    failure = null;
    notifyListeners();
  }

  Future<void> locate() => _run(LocationFailure.gps, () async {
    selected = await device.current();
    route = null;
  });

  Future<void> save() => _run(LocationFailure.save, () async {
    final point = selected!;
    await SaveShopLocation(locations)(point);
    destination = point;
  });

  Future<void> calculate() => _run(LocationFailure.route, () async {
    route = await routes!.calculate(selected!, destination!);
  });

  Future<void> _run(LocationFailure kind, Future<void> Function() task) async {
    if (busy || _disposed) return;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      await task();
    } catch (_) {
      failure = kind;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
