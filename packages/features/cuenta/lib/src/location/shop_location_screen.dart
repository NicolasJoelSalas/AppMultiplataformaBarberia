import 'dart:async';

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

class _ShopLocationScreenState extends State<ShopLocationScreen>
    with WidgetsBindingObserver {
  static const _initialCenter = LatLng(-34.77, -58.27);
  final _map = MapController();
  late final ShopLocationViewModel _model;
  bool _mapReady = false;
  bool _confirmingExit = false;
  bool _followCamera = true;
  MapPoint? _lastCentered;
  ShopRoute? _lastRoute;

  String _text(String es, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : es;

  String _distance(double meters) => meters < 1000
      ? '${meters.ceil()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

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
    WidgetsBinding.instance.addObserver(this);
    _model.addListener(_updateCamera);
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
    _followCamera = true;
    await _model.locate();
    final selected = _model.selected;
    if (mounted &&
        _model.editing &&
        _model.failure == null &&
        _mapReady &&
        selected != null) {
      _map.move(_point(selected), 15);
    }
  }

  void _centerPosition() {
    final point = _model.selected;
    if (!_mapReady || point == null) return;
    _followCamera = true;
    _lastCentered = point;
    _map.move(_point(point), 16);
  }

  void _updateCamera() {
    if (!_mapReady) return;
    if (_model.tracking) {
      if (_followCamera && _lastCentered != _model.selected) _centerPosition();
      return;
    }
    final route = _model.route;
    if (route == null || route == _lastRoute) return;
    _lastRoute = route;
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: route.points.map(_point).toList(),
        padding: const EdgeInsets.all(44),
        maxZoom: 17,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _model.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _model.pause();
    }
  }

  Future<void> _confirmExit() async {
    if (_model.saving || !_model.hasUnsavedLocation || _confirmingExit) return;
    _confirmingExit = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _text(
            '¿Descartar la ubicación elegida?',
            'Discard the selected location?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text('Seguir editando', 'Keep editing')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text('Descartar', 'Discard')),
          ),
        ],
      ),
    );
    _confirmingExit = false;
    if (discard == true &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model.removeListener(_updateCamera);
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
      final tracking = _model.tracking;
      final remaining = _model.remainingMeters;
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
      final screen = Scaffold(
        appBar: AppBar(
          title: Text(
            editing
                ? _text('Ubicación de la barbería', 'Barbershop location')
                : _text('Cómo llegar', 'Directions'),
          ),
        ),
        body: Column(
          children: [
            if (_model.busy || _model.routing || _model.waitingForFix)
              const LinearProgressIndicator(),
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
                  if (tracking)
                    Text(
                      _text(
                        'Siguiendo tu ubicación',
                        'Following your location',
                      ),
                    ),
                  if (route != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      tracking && remaining != null
                          ? _text(
                              '${_distance(remaining)} restantes',
                              '${_distance(remaining)} remaining',
                            )
                          : '${_distance(route.meters)} · ${(route.seconds / 60).ceil()} min',
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
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture) _followCamera = false;
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
                    onPressed: canSelect && !tracking ? _locate : null,
                    icon: const Icon(Icons.my_location),
                    label: Text(_text('Usar mi ubicación', 'Use my location')),
                  ),
                  if (tracking)
                    TextButton(
                      onPressed: selected == null || _model.waitingForFix
                          ? null
                          : _centerPosition,
                      child: Text(_text('Centrar', 'Recenter')),
                    ),
                  if (tracking)
                    TextButton(
                      onPressed: _model.stopTracking,
                      child: Text(
                        _text('Detener seguimiento', 'Stop following'),
                      ),
                    ),
                  FilledButton(
                    onPressed:
                        canSelect &&
                            !_model.routing &&
                            (editing
                                ? _model.hasUnsavedLocation
                                : selected != null)
                        ? _action
                        : null,
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
      return PopScope(
        canPop: !_model.saving && !_model.hasUnsavedLocation,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_confirmExit());
        },
        child: screen,
      );
    },
  );
}
