import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_data/core_data.dart';
import 'package:domain/domain.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthDependencies {
  const AuthDependencies._(
    this.login,
    this.profiles,
    this.services,
    this.agenda,
    this.booking,
    this.bookingPhotos,
  );

  final LoginViewModel login;
  final ProfileRepository profiles;
  final BarberServiceRepository services;
  final AgendaRepository agenda;
  final BookingRepository booking;
  final BookingPhotoRepository bookingPhotos;

  static Future<AuthDependencies> create(SharedPreferences preferences) async {
    final auth = FirebaseAuthRepository(FirebaseAuth.instance);
    final clientes = FirestoreClienteRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
      preferences,
    );
    final login = LoginViewModel(
      login: LoginUseCase(auth),
      register: RegisterUseCase(auth),
      loginWithGoogle: LoginWithGoogleUseCase(auth),
      ensureProfile: EnsureClienteProfileUseCase(clientes),
      logout: LogoutUseCase(auth, auth, clientes),
      initiallyLoggedIn: auth.isLoggedIn,
    );
    final services = FirestoreBarberServiceRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
    final agenda = FirestoreAgendaRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
    final booking = FirestoreBookingRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
    return AuthDependencies._(
      login,
      clientes,
      services,
      agenda,
      booking,
      await _createBookingPhotos(),
    );
  }

  static Future<BookingPhotoRepository> _createBookingPhotos() async {
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
