import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreClienteRepository
    implements ClienteRepository, ProfileRepository {
  FirestoreClienteRepository(this.firestore, this.auth, this.preferences);
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final SharedPreferences preferences;
  String _key(String uid) => 'validated_profile_$uid';
  String _snapshotKey(String uid) => 'account_profile_$uid';

  DocumentReference<Map<String, dynamic>> _barber(String uid) =>
      firestore.collection('barberos').doc(uid);
  DocumentReference<Map<String, dynamic>> _client(String uid) =>
      firestore.collection('clientes').doc(uid);

  @override
  Future<AppResult<void>> ensureCurrentProfile() async {
    final user = auth.currentUser;
    if (user == null) return const Failure(AuthError.profileSignin);
    if (preferences.getBool(_key(user.uid)) == true) return const Success(null);
    final email = user.email;
    if (email == null) return const Failure(AuthError.missingEmail);
    final barber = _barber(user.uid);
    final client = _client(user.uid);
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
  Future<AppResult<AccountProfile>> loadProfile() async {
    final user = auth.currentUser;
    if (user == null) return const Failure(AuthError.profileSignin);
    const server = GetOptions(source: Source.server);
    try {
      final barber = await _barber(user.uid).get(server);
      final role = _role(barber);
      final profile = barber.exists
          ? barber
          : await _client(user.uid).get(server);
      if (!profile.exists) {
        await preferences.remove(_snapshotKey(user.uid));
        return const Failure(AuthError.profileLoad);
      }
      final storedName = profile.data()?['Nombre'];
      final name = storedName is String ? storedName : '';
      return await _validatedProfile(user, name, role);
    } on FirebaseException catch (error) {
      if (_connectionError(error) && auth.currentUser?.uid == user.uid) {
        if (preferences.getStringList(_snapshotKey(user.uid)) case [
          final storedRole,
          final name,
        ]) {
          final role = switch (storedRole) {
            'client' => AccountRole.client,
            'barber' => AccountRole.barber,
            _ => null,
          };
          if (role != null) {
            return Success(
              AccountProfile(
                name: name,
                email: user.email ?? '',
                role: role,
                offline: true,
              ),
            );
          }
        }
      }
      if (!_connectionError(error)) {
        await preferences.remove(_snapshotKey(user.uid));
      }
      return Failure(_profileError(error, AuthError.profileLoad));
    } on StateError {
      await preferences.remove(_snapshotKey(user.uid));
      return const Failure(AuthError.profilePermission);
    }
  }

  @override
  Future<AppResult<AccountProfile>> updateName(String name) async {
    final user = auth.currentUser;
    if (user == null) return const Failure(AuthError.profileSignin);
    try {
      final role = await firestore.runTransaction<AccountRole>((tx) async {
        if (auth.currentUser?.uid != user.uid) {
          throw StateError('The signed-in account changed.');
        }
        final barber = await tx.get(_barber(user.uid));
        final role = _role(barber);
        final target = barber.exists ? barber : await tx.get(_client(user.uid));
        if (!target.exists) throw StateError('Account profile missing.');
        tx.update(target.reference, {'Nombre': name});
        return role;
      });
      return await _validatedProfile(user, name, role);
    } on FirebaseException catch (error) {
      return Failure(_profileError(error, AuthError.profileSave));
    } on StateError {
      return const Failure(AuthError.profilePermission);
    }
  }

  AccountRole _role(DocumentSnapshot<Map<String, dynamic>> barber) {
    if (!barber.exists) return AccountRole.client;
    if (barber.data()?['Estado'] == true) return AccountRole.barber;
    throw StateError('The barber account is disabled.');
  }

  Future<AppResult<AccountProfile>> _validatedProfile(
    User user,
    String name,
    AccountRole role,
  ) async {
    if (auth.currentUser?.uid != user.uid) {
      return const Failure(AuthError.profileSignin);
    }
    await preferences.setStringList(_snapshotKey(user.uid), [role.name, name]);
    return Success(
      AccountProfile(name: name, email: user.email ?? '', role: role),
    );
  }

  bool _connectionError(FirebaseException error) =>
      error.code == 'unavailable' || error.code == 'deadline-exceeded';

  AuthError _profileError(FirebaseException error, AuthError fallback) {
    if (_connectionError(error)) return AuthError.network;
    if (error.code == 'permission-denied') return AuthError.profilePermission;
    return fallback;
  }

  @override
  Future<void> clearValidatedSession(String uid) async {
    await preferences.remove(_snapshotKey(uid));
    await preferences.remove(_key(uid));
  }
}
