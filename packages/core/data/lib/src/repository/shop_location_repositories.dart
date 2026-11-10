import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network/network.dart';

class FirestoreShopLocationRepository implements ShopLocationRepository {
  FirestoreShopLocationRepository(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? (throw StateError('Sign in'));

  @override
  Future<MapPoint?> read({String? barberId}) async {
    final uid = _uid;
    final doc = await _firestore
        .collection('barberos')
        .doc(barberId ?? uid)
        .get(const GetOptions(source: Source.server));
    final data = doc.data();
    if (_uid != uid || data?['Estado'] != true) {
      throw StateError('Barbershop unavailable');
    }
    final point = data?['Ubicacion'];
    return point is GeoPoint ? MapPoint(point.latitude, point.longitude) : null;
  }

  @override
  Future<void> save(MapPoint point) async {
    final uid = _uid;
    final ref = _firestore.collection('barberos').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (_uid != uid || doc.data()?['Estado'] != true || !point.isValid) {
        throw StateError('Location cannot be saved');
      }
      transaction.update(ref, {
        'Ubicacion': GeoPoint(point.latitude, point.longitude),
        'UbicacionActualizadaEn': FieldValue.serverTimestamp(),
      });
    });
  }
}

class GeolocatorDeviceLocationRepository implements DeviceLocationRepository {
  const GeolocatorDeviceLocationRepository();

  @override
  Future<MapPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location is disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw StateError('Location permission was denied');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        timeLimit: Duration(seconds: 15),
      ),
    );
    return MapPoint(position.latitude, position.longitude);
  }
}

class OsrmShopRouteRepository implements ShopRouteRepository {
  OsrmShopRouteRepository(this._baseUrl);
  final Uri _baseUrl;

  @override
  Future<ShopRoute> calculate(MapPoint origin, MapPoint destination) async {
    if (!origin.isValid || !destination.isValid || _baseUrl.scheme != 'https') {
      throw ArgumentError('Invalid route request');
    }
    final coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';
    final uri = _baseUrl
        .resolve('route/v1/driving/$coordinates')
        .replace(
          queryParameters: {'overview': 'full', 'geometries': 'geojson'},
        );
    final json = await const NetworkClient().getJson(
      uri,
      timeout: const Duration(seconds: 12),
    ) as Map<String, dynamic>;
    final routes = json['routes'] as List?;
    if (json['code'] != 'Ok' || routes == null || routes.isEmpty) {
      throw StateError('Route unavailable');
    }
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final points = [
      for (final pair in geometry['coordinates'] as List)
        MapPoint((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
    ];
    final meters = (route['distance'] as num).toDouble();
    final seconds = (route['duration'] as num).toDouble();
    if (points.length < 2 ||
        points.any((point) => !point.isValid) ||
        !meters.isFinite ||
        meters < 0 ||
        !seconds.isFinite ||
        seconds < 0) {
      throw const FormatException('Invalid route');
    }
    return ShopRoute(points, meters, seconds);
  }
}
