import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'shop_location_view_model.dart';

class ShopLocationScreen extends StatefulWidget {
  const ShopLocationScreen({
    super.key,
    required this.locations,
    required this.device,
    this.barberId,
    this.routes,
  }) : assert(barberId == null || routes != null);

  final ShopLocationRepository locations;
  final DeviceLocationRepository device;
  final String? barberId;
  final ShopRouteRepository? routes;

  @override
  State<ShopLocationScreen> createState() => _ShopLocationScreenState();
}

class _ShopLocationScreenState extends State<ShopLocationScreen> {
  static const _initialCenter = LatLng(-34.77, -58.27);
  final _map = MapController();
  late final ShopLocationViewModel _model;
  bool _mapReady = false;

  String _text(String es, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : es;

  LatLng _point(MapPoint point) => LatLng(point.latitude, point.longitude);

  @override
  void initState() {
    super.initState();
    _model = ShopLocationViewModel(
      widget.locations,
      widget.device,
      barberId: widget.barberId,
      routes: widget.routes,
    );
    _load();
  }

  Future<void> _load() async {
    await _model.load();
    if (mounted) _centerDestination();
  }

  void _centerDestination() {
    final destination = _model.destination;
    if (_mapReady && destination != null) {
      _map.move(_point(destination), 15);
    }
  }

  Future<void> _locate() async {
    await _model.locate();
    if (mounted && _model.failure == null && _mapReady) {
      _map.move(_point(_model.selected!), 15);
    }
  }

  Future<void> _action() async {
    if (_model.editing) {
      await _model.save();
      if (mounted && _model.failure == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_text('Ubicación guardada.', 'Location saved.')),
          ),
        );
      }
      return;
    }
    await _model.calculate();
    final route = _model.route;
    if (mounted && _mapReady && route != null) {
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: route.points.map(_point).toList(),
          padding: const EdgeInsets.all(44),
          maxZoom: 17,
        ),
      );
    }
  }

  @override
  void dispose() {
    _model.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final destination = _model.destination;
      final selected = _model.selected;
      final route = _model.route;
      final editing = _model.editing;
      final canSelect =
          !_model.busy && _model.loaded && (editing || destination != null);
      final failure = switch (_model.failure) {
        LocationFailure.load => _text(
          'No se pudo consultar la ubicación.',
          'Could not load the location.',
        ),
        LocationFailure.gps => _text(
          'No se pudo usar el GPS. Revisá el permiso de ubicación o elegí un punto en el mapa.',
          'GPS is unavailable. Check the location permission or choose a point on the map.',
        ),
        LocationFailure.save => _text(
          'No se pudo guardar la ubicación.',
          'Could not save the location.',
        ),
        LocationFailure.route => _text(
          'No se pudo calcular el recorrido.',
          'Could not calculate directions.',
        ),
        null => null,
      };
      return Scaffold(
        appBar: AppBar(
          title: Text(
            editing
                ? _text('Ubicación de la barbería', 'Barbershop location')
                : _text('Cómo llegar', 'Directions'),
          ),
        ),
        body: Column(
          children: [
            if (_model.busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (failure != null) Text(failure),
                  if (_model.failure == LocationFailure.load)
                    TextButton(
                      onPressed: _load,
                      child: Text(_text('Reintentar', 'Retry')),
                    ),
                  if (_model.loaded && !editing && destination == null)
                    Text(
                      _text(
                        'La barbería todavía no publicó su ubicación.',
                        'This barber has not shared a location yet.',
                      ),
                    ),
                  if (_model.loaded && (editing || destination != null))
                    Text(
                      editing
                          ? _text(
                              'Marcá la barbería en el mapa o usá tu ubicación.',
                              'Mark the barbershop on the map or use your location.',
                            )
                          : _text(
                              'Marcá el punto de partida en el mapa o usá tu ubicación.',
                              'Mark your starting point on the map or use your location.',
                            ),
                    ),
                  if (route != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${(route.meters / 1000).toStringAsFixed(1)} km · ${(route.seconds / 60).ceil()} min',
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: 12,
                  maxZoom: 19,
                  onMapReady: () {
                    _mapReady = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _centerDestination();
                    });
                  },
                  onTap: canSelect
                      ? (_, point) => _model.select(
                          MapPoint(point.latitude, point.longitude),
                        )
                      : null,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ar.edu.unaj.am.myapplication',
                    maxNativeZoom: 19,
                  ),
                  if (route != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route.points.map(_point).toList(),
                          strokeWidth: 5,
                          color: Colors.blue.shade800,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if ((editing ? selected : destination) case final shop?)
                        Marker(
                          point: _point(shop),
                          child: const Icon(
                            Icons.store,
                            color: Colors.red,
                            size: 30,
                          ),
                        ),
                      if (!editing && selected != null)
                        Marker(
                          point: _point(selected),
                          child: const Icon(
                            Icons.place,
                            color: Colors.blue,
                            size: 30,
                          ),
                        ),
                    ],
                  ),
                  const SimpleAttributionWidget(
                    source: Text('© OpenStreetMap contributors'),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: canSelect ? _locate : null,
                    icon: const Icon(Icons.my_location),
                    label: Text(_text('Usar mi ubicación', 'Use my location')),
                  ),
                  FilledButton(
                    onPressed: canSelect && selected != null ? _action : null,
                    child: Text(
                      editing
                          ? _text('Guardar', 'Save')
                          : _text('Calcular recorrido', 'Calculate route'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
