import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreBarberServiceRepository implements BarberServiceRepository {
  const FirestoreBarberServiceRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _services =>
      _firestore.collection('servicios');

  DocumentReference<Map<String, dynamic>> _barber(String uid) =>
      _firestore.collection('barberos').doc(uid);

  @override
  String newServiceId() => _services.doc().id;

  @override
  Future<List<BarberService>> loadOwnServices() => _run((uid) async {
    const server = GetOptions(source: Source.server);
    _requireEnabled(await _barber(uid).get(server));
    final snapshot = await _services
        .where('BarberoId', isEqualTo: uid)
        .get(server);
    final services = snapshot.docs.map(_decode).toList();
    services.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.details.name.toLowerCase().compareTo(
        b.details.name.toLowerCase(),
      );
    });
    return services;
  });

  @override
  Future<void> save(
    String id,
    ServiceDetails details, {
    required bool create,
  }) => _mutate(id, (tx, ref, previous, uid) {
    final fields = {
      'NombreCorte': details.name,
      'Precio': details.priceCents / 100,
      'Duracion': details.durationMinutes,
    };
    if (previous.exists) {
      tx.update(ref, fields);
    } else if (create) {
      tx.set(ref, {
        ...fields,
        'BarberoId': uid,
        'Estado': true,
        'CreadoEn': FieldValue.serverTimestamp(),
      });
    } else {
      throw ServiceFailure.operation;
    }
  });

  @override
  Future<void> setActive(String id, bool active) =>
      _mutate(id, (tx, ref, previous, _) {
        if (!previous.exists) throw ServiceFailure.operation;
        tx.update(ref, {'Estado': active});
      });

  Future<void> _mutate(
    String id,
    void Function(
      Transaction tx,
      DocumentReference<Map<String, dynamic>> ref,
      DocumentSnapshot<Map<String, dynamic>> previous,
      String uid,
    )
    write,
  ) => _run((uid) async {
    final ref = _services.doc(id);
    await _firestore.runTransaction<void>((tx) async {
      _requireCurrentUser(uid);
      _requireEnabled(await tx.get(_barber(uid)));
      final previous = await tx.get(ref);
      _requireCurrentUser(uid);
      if (previous.exists && previous.data()?['BarberoId'] != uid) {
        throw ServiceFailure.permission;
      }
      write(tx, ref, previous, uid);
    });
  });

  BarberService _decode(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final price = data['Precio'];
    final priceCents = price is num
        ? ServiceDetails.parsePriceCents(price.toString())
        : null;
    final duration = data['Duracion'];
    if (priceCents == null || duration is! int) throw ServiceFailure.operation;
    final name = data['NombreCorte'];
    return BarberService(
      id: doc.id,
      details: ServiceDetails(
        name: name is String ? name : '',
        priceCents: priceCents,
        durationMinutes: duration,
      ),
      active: data['Estado'] == true,
    );
  }

  void _requireEnabled(DocumentSnapshot<Map<String, dynamic>> profile) {
    if (profile.data()?['Estado'] != true) throw ServiceFailure.permission;
  }

  void _requireCurrentUser(String uid) {
    if (_auth.currentUser?.uid != uid) throw ServiceFailure.permission;
  }

  Future<T> _run<T>(Future<T> Function(String uid) action) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw ServiceFailure.permission;
    try {
      final result = await action(uid);
      _requireCurrentUser(uid);
      return result;
    } on FirebaseException catch (error) {
      throw switch (error.code) {
        'unavailable' || 'deadline-exceeded' => ServiceFailure.network,
        'permission-denied' || 'unauthenticated' => ServiceFailure.permission,
        _ => ServiceFailure.operation,
      };
    }
  }
}
