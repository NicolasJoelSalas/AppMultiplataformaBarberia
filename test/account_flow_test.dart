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
      preferences: AppPreferences(storage),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
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
