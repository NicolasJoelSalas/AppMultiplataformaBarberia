import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_data/core_data.dart';
import 'package:domain/domain.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/appointment_alert_controller.dart';
import '../notifications/appointment_alerts.dart';
import '../notifications/web_appointment_alerts.dart';

class AuthDependencies {
  const AuthDependencies._(
    this.login,
    this.profiles,
    this.services,
    this.agenda,
    this.booking,
    this.bookingPhotos,
    this.work,
    this.locations,
    this.deviceLocation,
    this.routes,
    this.alerts,
  );

  final LoginViewModel login;
  final ProfileRepository profiles;
  final BarberServiceRepository services;
  final AgendaRepository agenda;
  final BookingRepository booking;
  final BookingPhotoRepository bookingPhotos;
  final WorkRepository work;
  final ShopLocationRepository locations;
  final DeviceLocationRepository deviceLocation;
  final ShopRouteRepository routes;
  final AppointmentAlerts? alerts;

  static Future<AuthDependencies> create(SharedPreferences preferences) async {
    final auth = FirebaseAuthRepository(FirebaseAuth.instance);
    final clientes = FirestoreClienteRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
      preferences,
    );
    final booking = FirestoreBookingRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
      storage: preferences,
    );
    final photos = await _createBookingPhotos();
    final work = FirestoreWorkRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
      photos,
      preferences,
    );
    final login = LoginViewModel(
      login: LoginUseCase(auth),
      register: RegisterUseCase(auth),
      loginWithGoogle: LoginWithGoogleUseCase(auth),
      googlePopup: kIsWeb ? auth.loginWithGooglePopup : null,
      ensureProfile: EnsureClienteProfileUseCase(clientes),
      logout: LogoutUseCase(auth, auth, clientes),
      initiallyLoggedIn: auth.isLoggedIn,
      initialUserId: auth.usuarioId,
      sessionChanges: auth.sessionChanges,
      clearAccountCache: (uid) async {
        await Future.wait([
          booking.clearLocal(uid),
          work.clearLocal(uid),
          clientes.clearValidatedSession(uid),
        ]);
      },
    );
    final services = FirestoreBarberServiceRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
    final agenda = FirestoreAgendaRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
    final alerts = await _createAlerts(auth, booking, preferences);
    return AuthDependencies._(
      login,
      clientes,
      services,
      agenda,
      booking,
      photos,
      work,
      FirestoreShopLocationRepository(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
      ),
      const GeolocatorDeviceLocationRepository(),
      OsrmShopRouteRepository(
        Uri.parse(
          const String.fromEnvironment(
            'OSRM_BASE_URL',
            defaultValue: 'https://router.project-osrm.org/',
          ),
        ),
      ),
      alerts,
    );
  }

  static Future<AppointmentAlerts?> _createAlerts(
    SesionActual session,
    AppointmentAlertRepository booking,
    SharedPreferences preferences,
  ) async {
    if (kIsWeb) return WebAppointmentAlerts(session, booking, preferences);
    if (!AppointmentAlertController.supported) return null;
    final controller = AppointmentAlertController(
      session,
      booking,
      preferences,
    );
    try {
      await controller.initialize();
      return controller;
    } catch (_) {
      controller.dispose();
      debugPrint('Could not initialize appointment alerts.');
      return null;
    }
  }

  static Future<CloudinaryBookingPhotoRepository> _createBookingPhotos() async {
    const cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
    const uploadPreset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');
    const fromDefines = CloudinaryBookingPhotoRepository(
      cloudName,
      uploadPreset,
    );
    if (cloudName.isNotEmpty ||
        uploadPreset.isNotEmpty ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return fromDefines;
    }

    try {
      final config = await const MethodChannel('barberapp/cloudinary')
          .invokeMapMethod<String, String>('read');
      return CloudinaryBookingPhotoRepository(
        config?['cloudName'] ?? '',
        config?['uploadPreset'] ?? '',
      );
    } on MissingPluginException {
      return fromDefines;
    } on PlatformException {
      return fromDefines;
    }
  }
}
