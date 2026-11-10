import 'dart:math' as math;

import 'shop_location.dart';

const _earthRadius = 6371000.0;
double _radians(double degrees) => degrees * math.pi / 180;

double _distance(MapPoint a, MapPoint b) {
  final lat = math.sin(_radians(b.latitude - a.latitude) / 2);
  final lon = math.sin(_radians(b.longitude - a.longitude) / 2);
  final h =
      lat * lat +
      math.cos(_radians(a.latitude)) *
          math.cos(_radians(b.latitude)) *
          lon *
          lon;
  return 2 * _earthRadius * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
}

/// Projects a GPS fix onto route segments, including long segments with no
/// nearby vertices. Scales the geometric progress to OSRM's reported distance.
({double deviation, double remaining}) routeProgress(
  MapPoint point,
  ShopRoute route,
) {
  if (route.points.length < 2) {
    return (deviation: double.infinity, remaining: route.meters);
  }
  final scale = math.cos(_radians(point.latitude)) * _earthRadius;
  double x(MapPoint value) =>
      _radians((value.longitude - point.longitude + 540) % 360 - 180) * scale;
  double y(MapPoint value) =>
      _radians(value.latitude - point.latitude) * _earthRadius;

  var closest = double.infinity;
  var progress = 0.0;
  var total = 0.0;
  for (var index = 1; index < route.points.length; index++) {
    final a = route.points[index - 1];
    final b = route.points[index];
    final ax = x(a);
    final ay = y(a);
    final dx = x(b) - ax;
    final dy = y(b) - ay;
    final lengthSquared = dx * dx + dy * dy;
    final fraction = lengthSquared == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
    final px = ax + fraction * dx;
    final py = ay + fraction * dy;
    final deviation = math.sqrt(px * px + py * py);
    final length = _distance(a, b);
    if (deviation < closest) {
      closest = deviation;
      progress = total + fraction * length;
    }
    total += length;
  }
  return (
    deviation: closest,
    remaining: total == 0
        ? 0.0
        : route.meters * (1 - progress / total).clamp(0.0, 1.0),
  );
}

class RouteDeviation {
  Duration? _since;

  void reset() => _since = null;

  bool shouldReroute({
    required double accuracy,
    required double? deviation,
    required Duration elapsed,
    required Duration? lastRequest,
  }) {
    if (accuracy > 50 || (deviation != null && deviation <= 50)) {
      reset();
      return false;
    }
    final since = _since ??= elapsed;
    if (elapsed - since < const Duration(seconds: 3) ||
        (lastRequest != null &&
            elapsed - lastRequest < const Duration(seconds: 10))) {
      return false;
    }
    reset();
    return true;
  }
}
