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
    await tester.tap(find.text('Mi cuenta').last);
    await tester.pumpAndSettle();
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

Future<SharedPreferences> _openApp(
  WidgetTester tester,
  _Session session,
) async {
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
      preferences: AppPreferences(storage),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
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
