import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreClienteRepository implements ClienteRepository {
  FirestoreClienteRepository(this.firestore, this.auth, this.preferences);
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final SharedPreferences preferences;
  String _key(String uid) => 'validated_profile_$uid';
  @override
  Future<AppResult<void>> ensureCurrentProfile() async {
    final user = auth.currentUser;
    if (user == null) return const Failure(AuthError.profileSignin);
    if (preferences.getBool(_key(user.uid)) == true) return const Success(null);
    final email = user.email;
    if (email == null) return const Failure(AuthError.missingEmail);
    final barber = firestore.collection('barberos').doc(user.uid);
    final client = firestore.collection('clientes').doc(user.uid);
    try {
      await firestore.runTransaction<void>((tx) async {
        final barberSnapshot = await tx.get(barber);
        final clientSnapshot = await tx.get(client);
        if (!barberSnapshot.exists && !clientSnapshot.exists) {
          final name = user.displayName ?? '';
          tx.set(client, {
            'Nombre': name.length > 120 ? name.substring(0, 120) : name,
            'Correo': email,
            'CreadoEn': FieldValue.serverTimestamp(),
          });
        }
      });
      await preferences.setBool(_key(user.uid), true);
      return const Success(null);
    } catch (_) {
      return const Failure(AuthError.profileLoad);
    }
  }

  @override
  Future<void> clearValidatedSession(String uid) async {
    await preferences.remove(_key(uid));
  }
}
