import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uses registration tokens to keep compatibility with the existing Kotlin
/// device records and FCM senders that address the `token` field.
class FirebasePushDevices {
  FirebasePushDevices(this._firestore, this._auth, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SharedPreferences _storage;
  static const _idKey = 'push.installationId';
  static const _timeout = Duration(seconds: 5);

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  // ignore: deprecated_member_use
  Stream<void> get tokenChanges => _messaging.onTokenRefresh.map((_) {});

  Future<String> _installationId() async {
    final stored = _storage.getString(_idKey);
    if (stored != null) return stored;
    final random = Random.secure();
    final id = base64Url.encode(List.generate(24, (_) => random.nextInt(256)));
    if (!await _storage.setString(_idKey, id)) {
      throw StateError('Could not store the push installation ID');
    }
    return id;
  }

  DocumentReference<Map<String, dynamic>> _barber(String uid) =>
      _firestore.collection('barberos').doc(uid);

  Future<String?> register(
    String uid,
    String? previousToken, {
    required bool Function() isActive,
  }) async {
    bool canWrite() => isActive() && _auth.currentUser?.uid == uid;
    if (!canWrite()) return null;
    // ignore: deprecated_member_use
    final token = await _messaging.getToken().timeout(_timeout);
    if (token == null || token.isEmpty || token.length > 4096 || !canWrite()) {
      return null;
    }
    if (token == previousToken) return token;
    final installationId = await _installationId();
    final barber = _barber(uid);
    final registered = await _firestore
        .runTransaction((tx) async {
          if (!canWrite()) return false;
          final profile = await tx.get(barber);
          if (!canWrite() || profile.data()?['Estado'] != true) return false;
          tx.set(barber.collection('dispositivos').doc(installationId), {
            'token': token,
            'actualizadoEn': FieldValue.serverTimestamp(),
          });
          return true;
        }, timeout: _timeout)
        .timeout(_timeout);
    return registered ? token : null;
  }

  Future<void> unregister(String uid) async {
    final id = _storage.getString(_idKey);
    await Future.wait([
      if (id != null && _auth.currentUser?.uid == uid)
        _firestore
            .runTransaction<void>((tx) async {
              if (_auth.currentUser?.uid != uid) return;
              tx.delete(_barber(uid).collection('dispositivos').doc(id));
            }, timeout: _timeout)
            .timeout(_timeout),
      // ignore: deprecated_member_use
      _messaging.deleteToken().timeout(_timeout),
    ]);
  }
}
