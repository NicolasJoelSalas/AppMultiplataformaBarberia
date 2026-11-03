import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_data/core_data.dart';
import 'package:domain/domain.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthDependencies {
  static Future<LoginViewModel> create() async {
    final auth = FirebaseAuthRepository(FirebaseAuth.instance);
    final clientes = FirestoreClienteRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
      await SharedPreferences.getInstance(),
    );
    return LoginViewModel(
      login: LoginUseCase(auth),
      register: RegisterUseCase(auth),
      loginWithGoogle: LoginWithGoogleUseCase(auth),
      ensureProfile: EnsureClienteProfileUseCase(clientes),
      logout: LogoutUseCase(auth, auth, clientes),
      initiallyLoggedIn: auth.isLoggedIn,
    );
  }
}
