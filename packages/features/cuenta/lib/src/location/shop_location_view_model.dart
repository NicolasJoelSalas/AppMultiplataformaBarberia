import 'dart:async';

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
  final _clock = Stopwatch()..start();
  final _deviation = RouteDeviation();

  MapPoint? destination;
  MapPoint? selected;
  ShopRoute? route;
  double? remainingMeters;
  LocationFailure? failure;
  bool busy = false;
  bool loaded = false;
  bool tracking = false;
  bool waitingForFix = false;
  bool routing = false;
  bool _disposed = false;
  bool _paused = false;
  int _routeVersion = 0;
  DateTime? _lastFix;
  Duration? _lastRequest;
  StreamSubscription<DeviceLocationFix>? _positions;

  bool get editing => barberId == null;

  Future<void> load() => _run(LocationFailure.load, () async {
    destination = await locations.read(barberId: barberId);
    selected = editing ? destination : null;
    loaded = true;
  });

  void select(MapPoint point) {
    if (busy || !point.isValid) return;
    _stopTracking();
    selected = point;
    route = null;
    remainingMeters = null;
    failure = null;
    notifyListeners();
    if (!editing) unawaited(calculate());
  }

  Future<void> locate() async {
    if (editing) {
      await _run(
        LocationFailure.gps,
        () async => selected = await device.current(),
      );
      return;
    }
    if (_disposed || destination == null) return;
    _stopTracking();
    tracking = true;
    waitingForFix = true;
    failure = null;
    notifyListeners();
    _subscribe();
  }

  void _subscribe() {
    if (!tracking || _paused || _positions != null) return;
    _positions = device.positions().listen(
      _onPosition,
      onError: (Object _) {
        if (_disposed || _paused || !tracking) return;
        _stopTracking();
        failure = LocationFailure.gps;
        notifyListeners();
      },
    );
  }

  void _onPosition(DeviceLocationFix fix) {
    if (!tracking ||
        _paused ||
        _disposed ||
        !fix.point.isValid ||
        !fix.accuracy.isFinite ||
        fix.accuracy < 0 ||
        (_lastFix != null && !fix.timestamp.isAfter(_lastFix!))) {
      return;
    }
    _lastFix = fix.timestamp;
    final first = waitingForFix;
    if (!first && fix.accuracy > 100) {
      _deviation.reset();
      return;
    }
    waitingForFix = false;
    selected = fix.point;
    if (first) {
      route = null;
      remainingMeters = null;
    }
    final currentRoute = route;
    final progress = currentRoute == null
        ? null
        : routeProgress(fix.point, currentRoute);
    if (progress != null && progress.deviation <= 50) {
      remainingMeters = progress.remaining;
    }
    notifyListeners();
    if (first ||
        (!routing &&
            _deviation.shouldReroute(
              accuracy: fix.accuracy,
              deviation: progress?.deviation,
              elapsed: _clock.elapsed,
              lastRequest: _lastRequest,
            ))) {
      unawaited(calculate());
    }
  }

  void pause() {
    _paused = true;
    _invalidateRouteRequest();
    unawaited(_positions?.cancel());
    _positions = null;
  }

  void resume() {
    if (!_paused || _disposed) return;
    _paused = false;
    _subscribe();
    if (!editing && selected != null && route == null) unawaited(calculate());
    notifyListeners();
  }

  void _invalidateRouteRequest() {
    _routeVersion++;
    routing = false;
    _deviation.reset();
  }

  void stopTracking() {
    _stopTracking();
    notifyListeners();
  }

  void _stopTracking() {
    tracking = false;
    waitingForFix = false;
    _lastFix = null;
    _invalidateRouteRequest();
    unawaited(_positions?.cancel());
    _positions = null;
  }

  Future<void> save() => _run(LocationFailure.save, () async {
    final point = selected!;
    await SaveShopLocation(locations)(point);
    destination = point;
  });

  Future<void> calculate() async {
    final origin = selected;
    final target = destination;
    if (_disposed ||
        _paused ||
        routing ||
        origin == null ||
        target == null ||
        routes == null ||
        waitingForFix) {
      return;
    }
    final version = ++_routeVersion;
    routing = true;
    failure = null;
    _lastRequest = _clock.elapsed;
    notifyListeners();
    try {
      final result = await routes!.calculate(origin, target);
      if (version != _routeVersion) return;
      route = result;
      final progress = tracking && selected != null
          ? routeProgress(selected!, result)
          : null;
      remainingMeters = progress != null && progress.deviation <= 50
          ? progress.remaining
          : result.meters;
    } catch (_) {
      if (version == _routeVersion) failure = LocationFailure.route;
    } finally {
      if (version == _routeVersion) {
        routing = false;
        notifyListeners();
      }
    }
  }

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
    _stopTracking();
    super.dispose();
  }
}
