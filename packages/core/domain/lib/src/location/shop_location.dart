class MapPoint {
  const MapPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
}

class ShopRoute {
  const ShopRoute(this.points, this.meters, this.seconds);
  final List<MapPoint> points;
  final double meters;
  final double seconds;
}

abstract interface class ShopLocationRepository {
  Future<MapPoint?> read({String? barberId});
  Future<void> save(MapPoint point);
}

class DeviceLocationFix {
  const DeviceLocationFix(this.point, this.accuracy, this.timestamp);
  final MapPoint point;
  final double accuracy;
  final DateTime timestamp;
}

abstract interface class DeviceLocationRepository {
  Future<MapPoint> current();
  Stream<DeviceLocationFix> positions();
}

abstract interface class ShopRouteRepository {
  Future<ShopRoute> calculate(MapPoint origin, MapPoint destination);
}

class SaveShopLocation {
  const SaveShopLocation(this.repository);
  final ShopLocationRepository repository;

  Future<void> call(MapPoint point) {
    if (!point.isValid) throw ArgumentError('Invalid coordinates');
    return repository.save(point);
  }
}
