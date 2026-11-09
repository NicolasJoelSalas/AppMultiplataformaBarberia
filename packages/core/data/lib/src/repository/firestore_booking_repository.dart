import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:domain/domain.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef _Fields = Map<String, dynamic>;
typedef _Doc = DocumentSnapshot<_Fields>;

class FirestoreBookingRepository implements BookingRepository {
  FirestoreBookingRepository(
    this._firestore,
    this._auth, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _server = GetOptions(source: Source.server);
  static const _equality = DeepCollectionEquality();
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DateTime Function() _now;

  CollectionReference<_Fields> get _barbers =>
      _firestore.collection('barberos');
  CollectionReference<_Fields> get _services =>
      _firestore.collection('servicios');
  CollectionReference<_Fields> get _appointments =>
      _firestore.collection('turnos');
  CollectionReference<_Fields> get _clients =>
      _firestore.collection('clientes');

  @override
  Future<List<BookingBarber>> loadBarbers() => _run((_) async {
    final result = await _barbers.where('Estado', isEqualTo: true).get(_server);
    return [
      for (final doc in result.docs)
        BookingBarber(doc.id, _text(doc.data()['Nombre'])),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  });

  @override
  Future<List<BookingService>> loadServices(String barberId) => _run((_) async {
    final result = await _services
        .where('BarberoId', isEqualTo: barberId)
        .get(_server);
    return [for (final doc in result.docs) ?_activeService(doc, barberId)]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  });

  @override
  Future<BookingWeek> loadWeek(
    String barberId,
    String serviceId,
    int offset, {
    String? editingId,
  }) => _run(
    (uid) => _firestore.runTransaction<BookingWeek>((tx) async {
      final barber = await tx.get(_barbers.doc(barberId));
      final zone = _enabledZone(barber);
      final calendar = AgendaCalendar(zone);
      final service = _activeService(
        await tx.get(_services.doc(serviceId)),
        barberId,
      );
      if (service == null) throw BookingFailure.serviceChanged;

      final now = _now();
      final monday = calendar.mondayFor(now, offset);
      BookingSlot? previousSlot;
      String? previousDay;
      if (editingId != null) {
        final previous = (await tx.get(_appointments.doc(editingId))).data();
        if (previous?['ClienteId'] != uid) throw BookingFailure.permission;
        final editable = _editable(previous!);
        if (previous['BarberoId'] == barberId) {
          previousSlot = editable;
          previousDay =
              _storedDayId(previous) ??
              _dayRef(
                barberId,
                calendar.startOfDay(calendar.dateOf(editable.start)),
              ).id;
        }
      }
      final sources = <String, _Doc>{};
      final slots = <BookingSlot>[];
      for (var offset = 0; offset < 6; offset++) {
        final date = monday.add(Duration(days: offset));
        final doc = await tx.get(_dayRef(barberId, calendar.startOfDay(date)));
        var day = await _publishedDay(
          tx,
          doc,
          barber,
          zone,
          calendar,
          date,
          sources,
        );
        if (doc.id == previousDay && previousSlot != null) {
          day = day.release(previousSlot);
        }
        slots.addAll(
          day.availableSlots(
            service.minutes,
            now,
            preferred: previousSlot?.start,
          ),
        );
      }
      _requireUser(uid);
      return BookingWeek(monday, zone, slots);
    }),
  );

  @override
  String newRequestId() => _appointments.doc().id;

  @override
  Future<void> confirm(
    BookingRequest request, {
    Appointment? original,
  }) => _run((uid) async {
    await _firestore.runTransaction<void>((tx) async {
      _requireUser(uid);
      final turn = _appointments.doc(original?.id ?? request.id);
      final previous = (await tx.get(turn)).data();
      final slot = request.slot;
      BookingSlot? previousSlot;
      if (original == null && previous != null) {
        if (previous['ClienteId'] == uid &&
            AppointmentStatus.fromStored(previous['Estado']) !=
                AppointmentStatus.canceled &&
            _matchesRequest(previous, request)) {
          return;
        }
        throw BookingFailure.unavailable;
      }
      if (original != null) {
        if (previous?['ClienteId'] != uid) throw BookingFailure.permission;
        previousSlot = _editable(previous!);
        if (!_matchesOriginal(previous, original)) {
          if (_matchesRequest(previous, request)) return;
          throw BookingFailure.changed;
        }
      }

      if ((await tx.get(_barbers.doc(uid))).exists) {
        throw BookingFailure.permission;
      }
      final client = await tx.get(_clients.doc(uid));
      if (!client.exists) throw BookingFailure.permission;
      final barber = await tx.get(_barbers.doc(request.barberId));
      final zone = _enabledZone(barber);
      if (zone != request.zoneId) throw BookingFailure.unpublished;
      final service = _activeService(
        await tx.get(_services.doc(request.serviceId)),
        request.barberId,
      );
      if (service == null ||
          slot.end.difference(slot.start) !=
              Duration(minutes: service.minutes)) {
        throw BookingFailure.serviceChanged;
      }

      final calendar = AgendaCalendar(zone);
      final date = calendar.dateOf(slot.start);
      final now = _now();
      final current = calendar.mondayFor(now, 0);
      final until = current.add(const Duration(days: 14));
      if (!slot.start.isAfter(now) ||
          date.isBefore(current) ||
          !date.isBefore(until) ||
          date.weekday == DateTime.sunday) {
        throw BookingFailure.unavailable;
      }
      final ref = _dayRef(request.barberId, calendar.startOfDay(date));
      final doc = await tx.get(ref);
      var day = await _publishedDay(tx, doc, barber, zone, calendar, date, {});
      DocumentReference<_Fields>? origin;
      String? released;
      if (previousSlot != null) {
        origin = await _origin(tx, previous!, previousSlot);
        if (origin.id == ref.id) {
          day = day.release(previousSlot);
        } else {
          final originalDay = _decodeDay(
            await tx.get(origin),
            _text(previous['BarberoId']),
          );
          released = originalDay.release(previousSlot).occupation;
        }
      }
      final occupied = day.reserve(slot);
      _requireUser(uid);

      final fields = <String, dynamic>{
        'BarberoId': request.barberId,
        'ServicioId': request.serviceId,
        'Inicio': Timestamp.fromDate(slot.start),
        'Fin': Timestamp.fromDate(slot.end),
        'Estado': 'confirmado',
        'HorarioId': '${request.barberId}_${slot.start.millisecondsSinceEpoch}',
        'DiaId': ref.id,
        'AgendaId': doc.data()!['AgendaId'],
        'ReservaVersion': 3,
        'DuracionMinutos': service.minutes,
      };
      if (origin == null) {
        tx.set(turn, {
          ...fields,
          'ClienteId': uid,
          'CreadoEn': FieldValue.serverTimestamp(),
          if (request.referenceUrl != null)
            'ReferenciaCorteUrl': request.referenceUrl,
        });
      } else {
        tx.update(turn, {
          ...fields,
          'DiaAnteriorId': origin.id,
          if (request.changeReference)
            'ReferenciaCorteUrl': request.referenceUrl ?? FieldValue.delete(),
        });
        if (released != null) {
          tx.update(origin, {'Ocupacion': released, 'UltimoTurnoId': turn.id});
        }
      }
      tx.update(ref, {'Ocupacion': occupied, 'UltimoTurnoId': turn.id});
      if (_text(client.data()?['Nombre']).trim().isEmpty) {
        tx.update(client.reference, {'Nombre': request.clientName});
      }
    });
  });

  @override
  Future<void> cancel(String id) => _run((uid) async {
    await _firestore.runTransaction<void>((tx) async {
      final turn = _appointments.doc(id);
      final previous = (await tx.get(turn)).data();
      if (previous == null ||
          (previous['ClienteId'] != uid && previous['BarberoId'] != uid)) {
        throw BookingFailure.permission;
      }
      if (AppointmentStatus.fromStored(previous['Estado']) ==
          AppointmentStatus.canceled) {
        return;
      }
      final slot = _editable(previous);
      if (previous['BarberoId'] == uid &&
          (await tx.get(_barbers.doc(uid))).data()?['Estado'] != true) {
        throw BookingFailure.permission;
      }
      final origin = await _origin(tx, previous, slot);
      final day = _decodeDay(
        await tx.get(origin),
        _text(previous['BarberoId']),
      );
      final occupation = day.release(slot).occupation;
      _requireUser(uid);
      tx.update(turn, {
        'Estado': 'cancelado',
        'CanceladoEn': FieldValue.serverTimestamp(),
        'CanceladoPor': uid,
        'DiaId': origin.id,
        'DiaAnteriorId': origin.id,
      });
      tx.update(origin, {'Ocupacion': occupation, 'UltimoTurnoId': id});
    });
  });

  BookingSlot _editable(_Fields previous) {
    final start = _instant(previous['Inicio']);
    final end = _instant(previous['Fin']);
    if (AppointmentStatus.fromStored(previous['Estado']) !=
            AppointmentStatus.pending ||
        start == null ||
        !start.isAfter(_now()) ||
        end == null) {
      throw BookingFailure.notEditable;
    }
    return BookingSlot(start, end);
  }

  @override
  Future<void> complete(String id) => _run((uid) async {
    await _firestore.runTransaction<void>((tx) async {
      final turn = _appointments.doc(id);
      final fields = (await tx.get(turn)).data();
      final barber = await tx.get(_barbers.doc(uid));
      if (fields == null ||
          fields['BarberoId'] != uid ||
          barber.data()?['Estado'] != true) {
        throw BookingFailure.permission;
      }
      final status = AppointmentStatus.fromStored(fields['Estado']);
      if (status == AppointmentStatus.completed) return;
      if (status != AppointmentStatus.pending ||
          _instant(fields['Inicio'])?.isAfter(_now()) != false) {
        throw BookingFailure.notCompletable;
      }
      final serviceId = _text(fields['ServicioId']);
      if (serviceId.trim().isEmpty || serviceId.contains('/')) {
        throw BookingFailure.invalidServicePrice;
      }
      final price = (await tx.get(_services.doc(serviceId))).data()?['Precio'];
      if (_priceCents(price) == null) throw BookingFailure.invalidServicePrice;
      _requireUser(uid);
      tx.update(turn, {
        'Estado': 'realizado',
        'PrecioCobrado': price,
        'RealizadoEn': FieldValue.serverTimestamp(),
      });
    });
  });

  bool _matchesOriginal(_Fields previous, Appointment original) =>
      _text(previous['BarberoId']) == original.barberId &&
      _text(previous['ServicioId']) == original.serviceId &&
      _instant(previous['Inicio'])?.microsecondsSinceEpoch ==
          original.start?.microsecondsSinceEpoch &&
      _instant(previous['Fin'])?.microsecondsSinceEpoch ==
          original.end?.microsecondsSinceEpoch &&
      previous['ReferenciaCorteUrl'] == original.referenceUrl;

  bool _matchesRequest(_Fields previous, BookingRequest request) =>
      previous['BarberoId'] == request.barberId &&
      previous['ServicioId'] == request.serviceId &&
      _instant(previous['Inicio'])?.isAtSameMomentAs(request.slot.start) ==
          true &&
      _instant(previous['Fin'])?.isAtSameMomentAs(request.slot.end) == true &&
      (!request.changeReference ||
          previous['ReferenciaCorteUrl'] == request.referenceUrl);

  String? _storedDayId(_Fields fields) {
    final id = fields['DiaId'];
    if (id == null) return null;
    if (id is! String || id.isEmpty || id.contains('/')) {
      throw BookingFailure.unpublished;
    }
    return id;
  }

  Future<DocumentReference<_Fields>> _origin(
    Transaction tx,
    _Fields previous,
    BookingSlot slot,
  ) async {
    final id = _storedDayId(previous);
    if (id != null) return _firestore.collection('disponibilidad').doc(id);
    final barberId = _text(previous['BarberoId']);
    if (barberId.isEmpty) throw BookingFailure.unpublished;
    final zone = (await tx.get(_barbers.doc(barberId))).data()?['ZonaHoraria'];
    if (zone is! String) throw BookingFailure.unpublished;
    final calendar = AgendaCalendar(zone);
    return _dayRef(barberId, calendar.startOfDay(calendar.dateOf(slot.start)));
  }

  @override
  Stream<List<Appointment>> watchAppointments(AccountRole role) async* {
    final uid = _uid();
    final roleField = role == AccountRole.barber ? 'BarberoId' : 'ClienteId';
    yield* _appointments
        .where(roleField, isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .asyncMap((snapshot) async {
          _requireUser(uid);
          if (snapshot.metadata.isFromCache) throw BookingFailure.network;
          final records = snapshot.docs;
          final barbers = await _readNames(
            _barbers,
            records.map((doc) => doc.data()['BarberoId']),
          );
          final clients = role == AccountRole.barber
              ? await _readNames(
                  _clients,
                  records.map((doc) => doc.data()['ClienteId']),
                )
              : const <String, _Fields>{};
          final services = await _readNames(
            _services,
            records.map((doc) => doc.data()['ServicioId']),
          );
          _requireUser(uid);

          return records.map((doc) {
            final record = doc.data();
            final barber = barbers[record['BarberoId']];
            final participant = role == AccountRole.barber
                ? clients[record['ClienteId']]
                : barber;
            final zone = barber?['ZonaHoraria'];
            return Appointment(
              id: doc.id,
              chargedPriceCents: _priceCents(record['PrecioCobrado']),
              barberId: _text(record['BarberoId']),
              serviceId: _text(record['ServicioId']),
              referenceUrl: record['ReferenciaCorteUrl'] is String
                  ? record['ReferenciaCorteUrl'] as String
                  : null,
              serviceName: _text(
                services[record['ServicioId']]?['NombreCorte'],
              ),
              participantName: _text(participant?['Nombre']),
              zoneId: zone is String ? zone : null,
              start: _instant(record['Inicio']),
              end: _instant(record['Fin']),
              status: AppointmentStatus.fromStored(record['Estado']),
            );
          }).toList();
        })
        .handleError((Object error) {
          throw _failure(error);
        });
  }

  Future<Map<String, _Fields>> _readNames(
    CollectionReference<_Fields> collection,
    Iterable<Object?> values,
  ) async {
    final ids = values
        .whereType<String>()
        .where((id) => id.isNotEmpty && !id.contains('/'))
        .toSet();
    final entries = await Future.wait(
      ids.map((id) async {
        try {
          final doc = await collection.doc(id).get(_server);
          return MapEntry(id, doc.data() ?? <String, dynamic>{});
        } on FirebaseException {
          // Historical appointments remain visible if a linked profile is gone.
          return MapEntry(id, <String, dynamic>{});
        }
      }),
    );
    return Map.fromEntries(entries);
  }

  DocumentReference<_Fields> _dayRef(String barberId, DateTime start) =>
      _firestore
          .collection('disponibilidad')
          .doc('${barberId}_${start.millisecondsSinceEpoch}');

  Future<BookingDay> _publishedDay(
    Transaction tx,
    _Doc doc,
    _Doc barber,
    String zone,
    AgendaCalendar calendar,
    DateTime date,
    Map<String, _Doc> sources,
  ) async {
    final fields = doc.data();
    final agendaId = fields?['AgendaId'];
    final day = _decodeDay(doc, barber.id);
    if (fields == null ||
        fields['ZonaHoraria'] != zone ||
        barber.data()?['ReservasVersion'] != 3 ||
        (fields['PublicacionPendiente'] ?? false) != false ||
        agendaId is! String ||
        agendaId.isEmpty ||
        agendaId.contains('/') ||
        !day.availability.start.isAtSameMomentAs(calendar.startOfDay(date)) ||
        !day.availability.end.isAtSameMomentAs(
          calendar.startOfDay(date.add(const Duration(days: 1))),
        )) {
      throw BookingFailure.unpublished;
    }
    final source = sources[agendaId] ??= await tx.get(
      barber.reference.collection('agenda').doc(agendaId),
    );
    if (!source.exists || !_equality.equals(fields['Agenda'], source.data())) {
      throw BookingFailure.unpublished;
    }
    return day;
  }

  BookingDay _decodeDay(_Doc doc, String barberId) {
    final fields = doc.data();
    final start = _instant(fields?['Inicio']);
    final end = _instant(fields?['Fin']);
    final attention = fields?['Atencion'];
    final occupation = fields?['Ocupacion'];
    if (fields?['BarberoId'] != barberId ||
        start == null ||
        end == null ||
        attention is! String ||
        occupation is! String) {
      throw BookingFailure.unpublished;
    }
    return BookingDay(AgendaAvailability(start, end, attention), occupation);
  }

  BookingService? _activeService(_Doc doc, String barberId) {
    final data = doc.data();
    final duration = data?['Duracion'];
    if (data == null ||
        (data['Estado'] ?? data['Activo']) != true ||
        data['BarberoId'] != barberId ||
        duration is! int ||
        duration < ServiceDetails.minDuration ||
        duration > ServiceDetails.maxDuration) {
      return null;
    }
    final price = data['Precio'];
    return BookingService(
      doc.id,
      _text(data['NombreCorte']),
      duration,
      _priceCents(price),
    );
  }

  String _enabledZone(_Doc barber) {
    final data = barber.data();
    if (data?['Estado'] != true) throw BookingFailure.unavailable;
    final zone = data?['ZonaHoraria'];
    if (zone is! String) throw BookingFailure.unpublished;
    return zone;
  }

  String _text(Object? value) => value is String ? value : '';
  int? _priceCents(Object? value) =>
      value is num ? ServiceDetails.parsePriceCents(value.toString()) : null;
  DateTime? _instant(Object? value) =>
      value is Timestamp ? value.toDate() : null;

  String _uid() => _auth.currentUser?.uid ?? (throw BookingFailure.permission);

  void _requireUser(String uid) {
    if (_auth.currentUser?.uid != uid) throw BookingFailure.permission;
  }

  Future<T> _run<T>(Future<T> Function(String uid) action) async {
    final uid = _uid();
    try {
      final result = await action(uid);
      _requireUser(uid);
      return result;
    } on FirebaseException catch (error) {
      throw _failure(error);
    } on AgendaProblem {
      throw BookingFailure.unpublished;
    }
  }

  BookingFailure _failure(Object error) {
    if (error is BookingFailure) return error;
    return switch (error is FirebaseException ? error.code : null) {
      'unavailable' || 'deadline-exceeded' => BookingFailure.network,
      'permission-denied' || 'unauthenticated' => BookingFailure.permission,
      _ => BookingFailure.operation,
    };
  }
}
