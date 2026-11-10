import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:domain/domain.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'appointment_storage.dart';

typedef _Fields = Map<String, dynamic>;
typedef _Ref = DocumentReference<_Fields>;
typedef _Doc = DocumentSnapshot<_Fields>;

class FirestoreAgendaRepository implements AgendaRepository {
  FirestoreAgendaRepository(
    this._firestore,
    this._auth, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _server = GetOptions(source: Source.server);
  static const _equality = DeepCollectionEquality();
  static const _weekdays = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
  ];
  static final _mask = RegExp(r'^[01]+$');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DateTime Function() _now;

  _Ref _barber(String uid) => _firestore.collection('barberos').doc(uid);
  _Ref _week(String uid, String id) =>
      _barber(uid).collection('agenda').doc(id);
  _Ref _day(String uid, AgendaAvailability day) => _firestore
      .collection('disponibilidad')
      .doc('${uid}_${day.start.millisecondsSinceEpoch}');

  @override
  Future<AgendaWeek> load(int offset) => _run((uid) async {
    final zone = _enabledZone(await _barber(uid).get(_server));
    final monday = AgendaCalendar(zone).mondayFor(_now(), offset);
    final id = monday.toIso8601String().split('T').first;
    final weekly = await _week(uid, id).get(_server);
    final source = weekly.exists
        ? weekly
        : await _week(uid, 'semanal').get(_server);
    final data = source.data();
    return AgendaWeek(
      monday: monday,
      zoneId: zone,
      days: [
        for (final name in _weekdays)
          if (data == null) const AgendaDay() else _decodeDay(data[name]),
      ],
    );
  });

  @override
  Future<void> save(AgendaWeek week) => _run((uid) async {
    final fields = _encode(week);
    await _firestore.runTransaction<void>((tx) async {
      final barber = await tx.get(_barber(uid));
      _requireWeek(barber, week);
      _requireUser(uid);
      tx.set(_week(uid, week.id), fields);
    });
  });

  @override
  Future<void> publish(AgendaWeek week, List<AgendaAvailability> days) => _run((
    uid,
  ) async {
    final agenda = _encode(week);
    final refs = [for (final day in days) _day(uid, day)];
    // Freeze the legacy reservation path before reading historical bookings.
    await _firestore.runTransaction<void>((tx) async {
      final barber = await _publicationSource(tx, uid, week, agenda);
      if (barber.data()?['ReservasVersion'] != 3) {
        tx.update(barber.reference, {'ReservasVersion': 3});
      }
    });
    final initial = await _bookings(uid, days);

    await _firestore.runTransaction<void>((tx) async {
      await _publicationSource(tx, uid, week, agenda);
      final stored = [for (final ref in refs) await tx.get(ref)];
      _requireUser(uid);
      for (final (index, day) in days.indexed) {
        final doc = stored[index];
        final bookings = initial.where(
          (booking) => day.containsStart(booking.start),
        );
        var occupation = doc.exists
            ? _occupation(doc, day)
            : day.emptyOccupation;
        for (final booking in bookings) {
          _requireDay(booking, doc.id);
          if (!doc.exists) {
            occupation = day.occupy(occupation, booking.start, booking.end);
          }
        }
        tx.set(refs[index], {
          'BarberoId': uid,
          'Inicio': Timestamp.fromDate(day.start),
          'Fin': Timestamp.fromDate(day.end),
          'Atencion': day.attention,
          'Ocupacion': occupation,
          'Agenda': agenda,
          'AgendaId': week.id,
          'ZonaHoraria': week.zoneId,
          'PublicacionPendiente': true,
        });
      }
    });

    // Read again now that the days are blocked. An edit could have moved
    // an appointment between the first query and the preparation transaction.
    for (final booking in await _bookings(uid, days)) {
      final day = days.firstWhere((day) => day.containsStart(booking.start));
      if (shouldCancelAfterAgendaChange(
        day,
        booking.status,
        booking.start,
        booking.end,
        _now(),
      )) {
        await _cancelExcluded(uid, week, agenda, day, booking.ref);
      }
    }

    await _firestore.runTransaction<void>((tx) async {
      await _publicationSource(tx, uid, week, agenda);
      final stored = [for (final ref in refs) await tx.get(ref)];
      _requireUser(uid);
      for (final (index, doc) in stored.indexed) {
        _requirePublishedDay(doc, week, agenda, days[index]);
        final data = doc.data()!;
        if (data['PublicacionPendiente'] == true) {
          tx.set(doc.reference, {
            for (final entry in data.entries)
              if (entry.key != 'UltimoTurnoId') entry.key: entry.value,
            'PublicacionPendiente': false,
          });
        }
      }
    });
  });

  Future<void> _cancelExcluded(
    String uid,
    AgendaWeek week,
    _Fields agenda,
    AgendaAvailability day,
    _Ref bookingRef,
  ) => _firestore.runTransaction<void>((tx) async {
    await _publicationSource(tx, uid, week, agenda);
    final currentDay = await tx.get(_day(uid, day));
    final currentBooking = await tx.get(bookingRef);
    _requireUser(uid);
    _requirePublishedDay(currentDay, week, agenda, day);
    // A concurrent publisher of the same agenda may already have finished.
    if (currentDay.data()?['PublicacionPendiente'] != true ||
        currentBooking.data()?['BarberoId'] != uid) {
      return;
    }
    final booking = _AgendaBooking.read(currentBooking);
    if (!shouldCancelAfterAgendaChange(
      day,
      booking.status,
      booking.start,
      booking.end,
      _now(),
    )) {
      return;
    }
    _requireDay(booking, currentDay.id);
    final occupation = day.release(
      _occupation(currentDay, day),
      booking.start,
      booking.end,
    );
    tx.update(bookingRef, {
      'Estado': 'cancelado',
      'CanceladoEn': FieldValue.serverTimestamp(),
      'CanceladoPor': uid,
      'DiaId': currentDay.id,
      'DiaAnteriorId': currentDay.id,
    });
    tx.update(currentDay.reference, {
      'Ocupacion': occupation,
      'UltimoTurnoId': bookingRef.id,
    });
  });

  Future<List<_AgendaBooking>> _bookings(
    String uid,
    List<AgendaAvailability> days,
  ) async {
    final snapshot = await _firestore
        .collection('turnos')
        .where('BarberoId', isEqualTo: uid)
        .get(_server);
    _requireUser(uid);
    final now = _now();
    final bookings = <_AgendaBooking>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final start = data['Inicio'];
      if (start is! Timestamp ||
          !days.any((day) => day.containsStart(start.toDate())) ||
          decodeAppointmentStatus(data['Estado']) ==
              AppointmentStatus.canceled) {
        continue;
      }
      final booking = _AgendaBooking.read(doc);
      if (booking.end.isAfter(now)) bookings.add(booking);
    }
    return bookings;
  }

  Future<_Doc> _publicationSource(
    Transaction tx,
    String uid,
    AgendaWeek week,
    _Fields agenda,
  ) async {
    final barber = await tx.get(_barber(uid));
    _requireWeek(barber, week);
    final saved = await tx.get(_week(uid, week.id));
    _requireUser(uid);
    if (!_equality.equals(saved.data(), agenda)) {
      throw const AgendaProblem(AgendaFailure.changed);
    }
    return barber;
  }

  void _requirePublishedDay(
    _Doc doc,
    AgendaWeek week,
    _Fields agenda,
    AgendaAvailability day,
  ) {
    final data = doc.data();
    if (data == null ||
        data['AgendaId'] != week.id ||
        data['ZonaHoraria'] != week.zoneId ||
        data['Atencion'] != day.attention ||
        !_equality.equals(data['Agenda'], agenda)) {
      throw const AgendaProblem(AgendaFailure.changed);
    }
  }

  String _occupation(_Doc doc, AgendaAvailability day) {
    final value = doc.data()?['Ocupacion'];
    if (value is! String ||
        value.length != day.attention.length ||
        !_mask.hasMatch(value)) {
      throw const AgendaProblem(AgendaFailure.availability);
    }
    return value;
  }

  void _requireDay(_AgendaBooking booking, String id) {
    if (booking.dayId != null && booking.dayId != id) {
      throw const AgendaProblem(AgendaFailure.zoneBookings);
    }
  }

  String _enabledZone(_Doc barber) {
    final data = barber.data();
    if (data?['Estado'] != true) {
      throw const AgendaProblem(AgendaFailure.permission);
    }
    final zone = data?['ZonaHoraria'];
    if (zone is! String) throw const AgendaProblem(AgendaFailure.zone);
    return zone;
  }

  void _requireWeek(_Doc barber, AgendaWeek week) {
    final zone = _enabledZone(barber);
    if (zone != week.zoneId) throw const AgendaProblem(AgendaFailure.changed);
    AgendaCalendar(zone).requireCurrentWeek(week.monday, _now());
  }

  void _requireUser(String uid) {
    if (_auth.currentUser?.uid != uid) {
      throw const AgendaProblem(AgendaFailure.permission);
    }
  }

  _Fields _encode(AgendaWeek week) => {
    for (final (index, day) in week.days.indexed)
      _weekdays[index]: {
        'Estado': day.open,
        'Franjas': [
          for (final span in day.spans) {'Inicio': span.start, 'Fin': span.end},
        ],
      },
  };

  AgendaDay _decodeDay(Object? value) {
    if (value is! Map || value['Estado'] is! bool) {
      throw const AgendaProblem(AgendaFailure.operation);
    }
    final open = value['Estado'] as bool;
    final spans = value['Franjas'];
    if (spans == null && !open) return const AgendaDay();
    if (spans is! List) throw const AgendaProblem(AgendaFailure.operation);
    return AgendaDay(
      open: open,
      spans: List.unmodifiable(
        spans.map((span) {
          if (span is! Map ||
              span['Inicio'] is! String ||
              span['Fin'] is! String) {
            throw const AgendaProblem(AgendaFailure.operation);
          }
          return AgendaSpan(span['Inicio'] as String, span['Fin'] as String);
        }),
      ),
    );
  }

  Future<T> _run<T>(Future<T> Function(String uid) action) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AgendaProblem(AgendaFailure.permission);
    try {
      final result = await action(uid);
      _requireUser(uid);
      return result;
    } on FirebaseException catch (error) {
      throw AgendaProblem(switch (error.code) {
        'unavailable' || 'deadline-exceeded' => AgendaFailure.network,
        'permission-denied' || 'unauthenticated' => AgendaFailure.permission,
        _ => AgendaFailure.operation,
      });
    }
  }
}

class _AgendaBooking {
  _AgendaBooking.read(_Doc doc)
    : ref = doc.reference,
      start = _date(doc, 'Inicio'),
      end = _date(doc, 'Fin'),
      dayId = doc.data()?['DiaId'],
      status = decodeAppointmentStatus(doc.data()?['Estado']);

  final _Ref ref;
  final DateTime start;
  final DateTime end;
  final Object? dayId;
  final AppointmentStatus status;

  static DateTime _date(_Doc doc, String key) {
    final value = doc.data()?[key];
    if (value is! Timestamp) {
      throw const AgendaProblem(AgendaFailure.availability);
    }
    return value.toDate();
  }
}
