import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:domain/domain.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';
import 'di/auth_dependencies.dart';
import 'di/firebase_web_options.dart';
import 'navigation/app_shell.dart';
import 'notifications/appointment_alerts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb && !hasFirebaseWebOptions) {
    runApp(
      const _StartupError(
        'Falta configurar Firebase para la versión web. Revisá las instrucciones del README.',
      ),
    );
    return;
  }
  try {
    await Firebase.initializeApp(options: kIsWeb ? firebaseWebOptions : null);
    if (kIsWeb) await FirebaseAuth.instance.authStateChanges().first;
    final storage = await SharedPreferences.getInstance();
    final auth = await AuthDependencies.create(storage);
    runApp(
      BarberApp(
        viewModel: auth.login,
        profiles: auth.profiles,
        services: auth.services,
        agenda: auth.agenda,
        booking: auth.booking,
        bookingPhotos: auth.bookingPhotos,
        work: auth.work,
        locations: auth.locations,
        deviceLocation: auth.deviceLocation,
        routes: auth.routes,
        alerts: auth.alerts,
        preferences: AppPreferences(storage),
      ),
    );
  } catch (_) {
    runApp(
      const _StartupError(
        'No se pudo iniciar Firebase. Revisá la configuración y volvé a abrir la aplicación.',
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('es'),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}

class BarberApp extends StatefulWidget {
  const BarberApp({
    super.key,
    required this.viewModel,
    required this.profiles,
    required this.services,
    required this.agenda,
    required this.booking,
    required this.bookingPhotos,
    required this.work,
    required this.locations,
    required this.deviceLocation,
    required this.routes,
    required this.preferences,
    this.alerts,
  });

  final LoginViewModel viewModel;
  final ProfileRepository profiles;
  final BarberServiceRepository services;
  final AgendaRepository agenda;
  final BookingRepository booking;
  final BookingPhotoRepository bookingPhotos;
  final WorkRepository work;
  final ShopLocationRepository locations;
  final DeviceLocationRepository deviceLocation;
  final ShopRouteRepository routes;
  final AppPreferences preferences;
  final AppointmentAlerts? alerts;
  @override
  State<BarberApp> createState() => _BarberAppState();
}

class _BarberAppState extends State<BarberApp> {
  final _google = GoogleTokenProvider();
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late int _sessionRevision;
  @override
  void initState() {
    super.initState();
    _sessionRevision = widget.viewModel.sessionRevision;
    widget.viewModel.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.viewModel.initialize();
    });
  }

  void _onSessionChanged() {
    final revision = widget.viewModel.sessionRevision;
    if (_sessionRevision == revision) return;
    _sessionRevision = revision;
    _messenger.currentState?.clearSnackBars();
    _navigator.currentState?.popUntil((route) => route.isFirst);
    unawaited(widget.alerts?.stop());
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onSessionChanged);
    widget.viewModel.dispose();
    widget.preferences.dispose();
    widget.alerts?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.preferences,
    builder: (context, _) => MaterialApp(
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
      locale: widget.preferences.language.locale,
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      title: 'Barber App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.preferences.themeMode,
      home: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final state = widget.viewModel.state;
          if (!state.isAuthenticated) {
            return LoginRoute(
              viewModel: widget.viewModel,
              getGoogleToken: _google.call,
            );
          }
          return AppShell(
            key: ValueKey(_sessionRevision),
            profiles: widget.profiles,
            services: widget.services,
            agenda: widget.agenda,
            booking: widget.booking,
            bookingPhotos: widget.bookingPhotos,
            work: widget.work,
            locations: widget.locations,
            deviceLocation: widget.deviceLocation,
            routes: widget.routes,
            alerts: widget.alerts,
            preferences: widget.preferences,
            onLogout: widget.viewModel.onLogout,
            loggingOut: state.isLoading,
            logoutError: state.error,
          );
        },
      ),
    ),
  );
}
