import 'dart:async';
import 'dart:typed_data';

import 'package:barberapp/app_preferences.dart';
import 'package:barberapp/main.dart';
import 'package:core_ui/core_ui.dart';
import 'package:domain/domain.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'app_language': 'es'}));

  testWidgets('client refreshes a lost slot and both roles see the booking', (
    tester,
  ) async {
    final bookings = _Bookings()
      ..failures.addAll([BookingFailure.unavailable, BookingFailure.network]);
    await _openApp(tester, _Session(AccountRole.client), booking: bookings);
    await tester.tap(find.text('Turnos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reservar turno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbero'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbería Centro').hitTestable().last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Servicio'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining('Corte clásico · ARS').hitTestable().last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próxima semana'));
    await tester.pumpAndSettle();

    await _scrollAndTap(tester, '09:00 – 09:40');
    await _confirmBooking(tester);
    expect(
      find.textContaining('El horario ya no está disponible'),
      findsOneWidget,
    );
    await tester.tap(find.text('Actualizar disponibilidad'));
    await tester.pumpAndSettle();
    expect(find.text('09:00 – 09:40'), findsNothing);
    await _scrollAndTap(tester, '09:40 – 10:20');
    await _confirmBooking(tester);
    expect(find.textContaining('Revisá tu conexión'), findsOneWidget);
    await _confirmBooking(tester);

    expect(bookings.requests.map((request) => request.id), [
      'booking-1',
      'booking-2',
      'booking-2',
    ]);
    expect(bookings.requests.last.clientName, 'Alex');
    expect(find.text('Turno reservado.'), findsOneWidget);
    expect(find.text('Barbero · Barbería Centro'), findsOneWidget);
    expect(find.text('09:40 – 10:20'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('Pendiente')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _openApp(tester, _Session(AccountRole.barber), booking: bookings);
    await tester.tap(find.text('Turnos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próxima semana'));
    await tester.pumpAndSettle();
    expect(find.text('Cliente · Alex'), findsOneWidget);
    expect(find.text('09:40 – 10:20'), findsOneWidget);
    expect(find.text('Reservar turno'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await bookings.updates.close();
  });

  testWidgets('client edits their profile and returns to login on sign-out', (
    tester,
  ) async {
    final session = _Session(AccountRole.client);
    await _openApp(tester, session);

    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Trabajos'), findsNothing);
    expect(find.text('Agenda'), findsNothing);
    await tester.tap(find.text('Mi cuenta').last);
    await tester.pumpAndSettle();
    expect(find.text('Mis servicios'), findsNothing);
    await tester.tap(find.text('Modificar perfil'));
    await tester.pumpAndSettle();

    expect(find.text('alex@example.test'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '   ');
    expect(session.names, isEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Ingresá tu nombre.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Alex Nuevo  ');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turnos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi cuenta').last);
    await tester.pumpAndSettle();
    expect(find.text('  Alex Nuevo  '), findsOneWidget);
    await _scrollAndTap(tester, 'Guardar cambios');
    await tester.pumpAndSettle();
    expect(session.names, ['Alex Nuevo']);
    expect(find.text('Cambios guardados.'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Alex Nuevo'), findsOneWidget);
    await _scrollAndTap(tester, 'Cerrar sesión');
    await tester.pumpAndSettle();
    expect(session.clearedUid, 'uid');
    expect(find.byType(LoginRoute), findsOneWidget);
  });

  testWidgets(
    'editing keeps the turn and its photo until removed, and barber can cancel',
    (tester) async {
      final bookings = _Bookings()..seed();
      await _openApp(tester, _Session(AccountRole.client), booking: bookings);
      await tester.tap(find.text('Turnos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Próxima semana'));
      await tester.pumpAndSettle();
      await _scrollAndTap(tester, 'Modificar turno');
      await tester.pumpAndSettle();
      expect(find.textContaining('Corte clásico · ARS'), findsWidgets);
      await _scrollAndTap(tester, '09:40 – 10:20');
      await _confirmBooking(tester, 'Confirmar modificación');
      expect(bookings.requests.single.id, 'original');
      expect(bookings.requests.single.changeReference, isFalse);
      expect(bookings.referenceUrl, 'legacy-reference');

      await _scrollAndTap(tester, 'Modificar turno');
      await tester.pumpAndSettle();
      await _scrollAndTap(tester, 'Quitar foto');
      await _confirmBooking(tester, 'Confirmar modificación');
      expect(bookings.requests.last.changeReference, isTrue);
      expect(bookings.referenceUrl, isNull);
      expect(find.text('09:40 – 10:20'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _openApp(tester, _Session(AccountRole.barber), booking: bookings);
      await tester.tap(find.text('Turnos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Próxima semana'));
      await tester.pumpAndSettle();
      expect(find.text('Modificar turno'), findsNothing);
      await _scrollAndTap(tester, 'Cancelar turno');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar turno'));
      await tester.pumpAndSettle();
      expect(bookings.canceledId, 'original');
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Cancelado'),
        ),
        findsOneWidget,
      );
      expect(find.text('Cancelar turno'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await bookings.updates.close();
    },
  );

  testWidgets('role failure is retriable and barber preferences persist', (
    tester,
  ) async {
    final session = _Session(AccountRole.barber)..failProfileLoad = true;
    final storage = await _openApp(tester, session);

    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.text('No se pudo cargar tu perfil. Reintentá con conexión.'),
      findsOneWidget,
    );
    session.failProfileLoad = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Reporte de ganancias'), findsOneWidget);
    await tester.tap(find.text('Mi cuenta').last);
    await tester.pumpAndSettle();
    expect(find.text('Cuenta de barbero'), findsOneWidget);
    expect(find.text('Mis servicios'), findsOneWidget);
    await _scrollAndTap(tester, 'Modo oscuro');
    await tester.pumpAndSettle();
    await _scrollAndTap(tester, 'Idioma');
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('My account'), findsWidgets);
    final restored = AppPreferences(storage);
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.language, AppLanguage.english);
    restored.dispose();
  });

  testWidgets(
    'barber completes an eligible appointment and badge and filters update',
    (tester) async {
      final bookings = _Bookings()..seed(reference: null);
      await _openApp(tester, _Session(AccountRole.barber), booking: bookings);
      final badge = find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.semanticsLabel == '1 turno pendiente',
      );
      expect(badge, findsWidgets);
      await tester.tap(find.text('Turnos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Próxima semana'));
      await tester.pumpAndSettle();
      final mark = find.widgetWithText(FilledButton, 'Marcar realizado');
      expect(tester.widget<FilledButton>(mark).onPressed, isNull);

      bookings.seed(startTime: DateTime.now(), reference: null);
      bookings.updates.add(null);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Esta semana'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pendiente'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(mark).onPressed, isNotNull);
      await _scrollAndTap(tester, 'Marcar realizado');
      await tester.pumpAndSettle();

      expect(bookings.completedId, 'original');
      expect(badge, findsNothing);
      expect(
        find.text('No hay turnos con el estado seleccionado para esta semana.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Completado'));
      await tester.pumpAndSettle();
      expect(find.text('Realizado'), findsOneWidget);
      expect(find.textContaining('Importe cobrado'), findsOneWidget);
      expect(mark, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await bookings.updates.close();
    },
  );

  testWidgets(
    'agenda preserves both drafts and retries a pending publication',
    (tester) async {
      final agenda = _Agenda()..failPublish = true;
      await _openApp(tester, _Session(AccountRole.barber), agenda: agenda);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();

      expect(find.text('Gestionar semana'), findsOneWidget);
      await tester.tap(find.text('Lunes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Próxima semana'));
      await tester.pumpAndSettle();
      expect(find.text('Inicio · --:--'), findsNothing);
      await tester.tap(find.text('Esta semana'));
      await tester.pumpAndSettle();
      expect(find.text('Inicio · --:--'), findsOneWidget);

      await tester.tap(find.text('Guardar y publicar semana'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Elegí una hora válida'), findsOneWidget);
      expect(agenda.saves, 0);

      await _pickDefaultTime(tester, 'Inicio · --:--');
      await _pickDefaultTime(tester, 'Fin · --:--');
      await tester.tap(find.text('Guardar y publicar semana'));
      await tester.pumpAndSettle();
      expect(find.textContaining('La agenda se guardó'), findsOneWidget);
      expect(agenda.saves, 1);
      expect(agenda.publications, 1);
      agenda.failPublish = false;

      await tester.tap(find.text('Guardar y publicar semana'));
      await tester.pumpAndSettle();
      expect(find.text('Franjas publicadas: 1'), findsOneWidget);
      expect(agenda.publications, 2);
    },
  );

  testWidgets('barber creates, edits and toggles the same service', (
    tester,
  ) async {
    final services = _Services()..failSave = true;
    await _openApp(tester, _Session(AccountRole.barber), services: services);
    await tester.tap(find.text('Mi cuenta').last);
    await tester.pumpAndSettle();
    await _scrollAndTap(tester, 'Mis servicios');
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Agregar servicio'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), ' Corte clásico ');
    await tester.enterText(fields.at(1), '12500,50');
    await tester.enterText(fields.at(2), '4');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar servicio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Revisá el nombre'), findsOneWidget);
    expect(services.savedIds, isEmpty);

    await tester.enterText(fields.at(2), '40');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar servicio'));
    await tester.pumpAndSettle();
    expect(find.text('Revisá tu conexión a Internet.'), findsOneWidget);
    services.failSave = false;
    await tester.tap(find.text('Guardar servicio'));
    await tester.pumpAndSettle();
    expect(services.savedIds, ['service-1', 'service-1']);
    expect(services.items['service-1']!.details.priceCents, 1250050);
    expect(find.text('Corte clásico'), findsOneWidget);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('12500.50'), findsOneWidget);
    await tester.enterText(fields.at(0), 'Corte y barba');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar servicio'));
    await tester.pumpAndSettle();
    expect(services.items.keys, ['service-1']);
    expect(find.text('Corte y barba'), findsOneWidget);

    await tester.tap(find.text('Dar de baja'));
    await tester.pumpAndSettle();
    expect(find.text('¿Dar de baja este servicio?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Dar de baja').last);
    await tester.pumpAndSettle();
    expect(services.items['service-1']!.active, isFalse);
    expect(find.text('Desactivado'), findsOneWidget);
    await tester.tap(find.text('Reactivar'));
    await tester.pumpAndSettle();
    expect(services.items['service-1']!.active, isTrue);
    expect(find.text('Activo'), findsOneWidget);
  });
}

Future<void> _scrollAndTap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.scrollUntilVisible(
    target,
    160,
    scrollable: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
}

Future<void> _confirmBooking(
  WidgetTester tester, [
  String label = 'Confirmar reserva',
]) async {
  await tester.pumpAndSettle();
  final button = find.widgetWithText(FilledButton, label);
  await tester.tap(button);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(AlertDialog), matching: button),
  );
  await tester.pumpAndSettle();
}

Future<void> _pickDefaultTime(WidgetTester tester, String field) async {
  await _scrollAndTap(tester, field);
  await tester.pumpAndSettle();
  final dialog = find.byType(TimePickerDialog);
  final strings = MaterialLocalizations.of(tester.element(dialog));
  await tester.tap(find.widgetWithText(TextButton, strings.okButtonLabel));
  await tester.pumpAndSettle();
}

Future<SharedPreferences> _openApp(
  WidgetTester tester,
  _Session session, {
  _Services? services,
  _Agenda? agenda,
  BookingRepository? booking,
}) async {
  final storage = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    BarberApp(
      viewModel: LoginViewModel(
        login: LoginUseCase(session),
        register: RegisterUseCase(session),
        loginWithGoogle: LoginWithGoogleUseCase(session),
        ensureProfile: EnsureClienteProfileUseCase(session),
        logout: LogoutUseCase(session, session, session),
        initiallyLoggedIn: session.isLoggedIn,
      ),
      profiles: session,
      services: services ?? _Services(),
      agenda: agenda ?? _Agenda(),
      booking: booking ?? _Bookings(),
      bookingPhotos: const _Photos(),
      preferences: AppPreferences(storage),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

class _Photos implements BookingPhotoRepository {
  const _Photos();

  @override
  Future<String> upload(Uint8List image) async =>
      'https://res.cloudinary.com/demo/image/upload/example.jpg';
}

class _Bookings implements BookingRepository {
  static const _zone = 'America/Argentina/Buenos_Aires';
  final updates = StreamController<void>.broadcast();
  final requests = <BookingRequest>[];
  final failures = <BookingFailure>[];
  BookingRequest? _booked;
  String? referenceUrl;
  String? canceledId;
  String? completedId;
  int _id = 0;

  void seed({DateTime? startTime, String? reference = 'legacy-reference'}) {
    final calendar = AgendaCalendar(_zone);
    final start =
        startTime ??
        calendar
            .startOfDay(calendar.mondayFor(DateTime.now(), 1))
            .add(const Duration(hours: 9));
    _booked = BookingRequest(
      id: 'original',
      barberId: 'barber',
      serviceId: 'corte',
      zoneId: _zone,
      slot: BookingSlot(start, start.add(const Duration(minutes: 40))),
      clientName: 'Alex',
    );
    referenceUrl = reference;
  }

  @override
  Future<List<BookingBarber>> loadBarbers() async => const [
    BookingBarber('barber', 'Barbería Centro'),
  ];

  @override
  Future<List<BookingService>> loadServices(String barberId) async => const [
    BookingService('corte', 'Corte clásico', 40, 1000000),
  ];

  @override
  Future<BookingWeek> loadWeek(
    String barberId,
    String serviceId,
    int offset, {
    String? editingId,
  }) async {
    final calendar = AgendaCalendar(_zone);
    final monday = calendar.mondayFor(DateTime.now(), offset);
    final first = calendar.startOfDay(monday).add(const Duration(hours: 9));
    final start = first.add(Duration(minutes: requests.isEmpty ? 0 : 40));
    return BookingWeek(monday, _zone, [
      if (editingId != null) ...[
        BookingSlot(first, first.add(const Duration(minutes: 40))),
        BookingSlot(
          first.add(const Duration(minutes: 40)),
          first.add(const Duration(minutes: 80)),
        ),
      ] else
        BookingSlot(start, start.add(const Duration(minutes: 40))),
    ]);
  }

  @override
  String newRequestId() => 'booking-${++_id}';

  @override
  Future<void> confirm(BookingRequest request, {Appointment? original}) async {
    requests.add(request);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    _booked = request;
    if (original == null || request.changeReference) {
      referenceUrl = request.referenceUrl;
    }
    updates.add(null);
  }

  @override
  Future<void> cancel(String id) async {
    canceledId = id;
    updates.add(null);
  }

  @override
  Future<void> complete(String id) async {
    completedId = id;
    updates.add(null);
  }

  @override
  Stream<List<Appointment>> watchAppointments(AccountRole role) async* {
    List<Appointment> snapshot() => [
      if (_booked case final booking?)
        Appointment(
          id: booking.id,
          barberId: booking.barberId,
          serviceId: booking.serviceId,
          referenceUrl: referenceUrl,
          chargedPriceCents: completedId == booking.id ? 1250050 : null,
          serviceName: 'Corte clásico',
          participantName: role == AccountRole.client
              ? 'Barbería Centro'
              : booking.clientName,
          zoneId: _zone,
          start: booking.slot.start,
          end: booking.slot.end,
          status: canceledId == booking.id
              ? AppointmentStatus.canceled
              : completedId == booking.id
              ? AppointmentStatus.completed
              : AppointmentStatus.pending,
        ),
    ];
    yield snapshot();
    yield* updates.stream.map((_) => snapshot());
  }
}

class _Agenda implements AgendaRepository {
  bool failPublish = false;
  int saves = 0;
  int publications = 0;

  @override
  Future<AgendaWeek> load(int offset) async => AgendaWeek(
    monday: DateTime.utc(2026, 11, 9 + 7 * offset),
    zoneId: 'America/Argentina/Buenos_Aires',
    days: List.filled(6, const AgendaDay()),
  );

  @override
  Future<void> save(AgendaWeek week) async => saves++;

  @override
  Future<void> publish(AgendaWeek week, List<AgendaAvailability> days) async {
    publications++;
    if (failPublish) throw const AgendaProblem(AgendaFailure.network);
  }
}

class _Services implements BarberServiceRepository {
  final items = <String, BarberService>{};
  final savedIds = <String>[];
  int _nextId = 0;
  bool failSave = false;

  @override
  String newServiceId() => 'service-${++_nextId}';

  @override
  Future<List<BarberService>> loadOwnServices() async => items.values.toList();

  @override
  Future<void> save(
    String id,
    ServiceDetails details, {
    required bool create,
  }) async {
    savedIds.add(id);
    if (failSave) throw ServiceFailure.network;
    items[id] = BarberService(
      id: id,
      details: details,
      active: items[id]?.active ?? true,
    );
  }

  @override
  Future<void> setActive(String id, bool active) async {
    items[id] = BarberService(
      id: id,
      details: items[id]!.details,
      active: active,
    );
  }
}

class _Session
    implements
        AuthRepository,
        SesionActual,
        ClienteRepository,
        ProfileRepository {
  _Session(this.role);

  final AccountRole role;
  final names = <String>[];
  String? clearedUid;
  bool failProfileLoad = false;

  @override
  String? usuarioId = 'uid';

  @override
  bool get isLoggedIn => usuarioId != null;

  @override
  Future<AppResult<AccountProfile>> loadProfile() async => failProfileLoad
      ? const Failure(AuthError.profileLoad)
      : Success(
          AccountProfile(
            name: names.isEmpty ? 'Alex' : names.last,
            email: 'alex@example.test',
            role: role,
          ),
        );

  @override
  Future<AppResult<AccountProfile>> updateName(String name) async {
    names.add(name);
    return loadProfile();
  }

  @override
  Future<AppResult<void>> ensureCurrentProfile() async => const Success(null);

  @override
  Future<void> clearValidatedSession(String uid) async => clearedUid = uid;

  @override
  Future<AppResult<void>> logout() async {
    usuarioId = null;
    return const Success(null);
  }

  @override
  Future<AppResult<void>> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AppResult<void>> loginWithGoogle(String idToken) =>
      throw UnimplementedError();

  @override
  Future<AppResult<void>> register(String email, String password) =>
      throw UnimplementedError();
}
