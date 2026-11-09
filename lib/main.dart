import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:domain/domain.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';
import 'di/auth_dependencies.dart';
import 'navigation/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    final storage = await SharedPreferences.getInstance();
    final auth = AuthDependencies.create(storage);
    runApp(
      BarberApp(
        viewModel: auth.login,
        profiles: auth.profiles,
        services: auth.services,
        agenda: auth.agenda,
        booking: auth.booking,
        preferences: AppPreferences(storage),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo iniciar Firebase. Revisá la configuración de Android y volvé a abrir la aplicación.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BarberApp extends StatefulWidget {
  const BarberApp({
    super.key,
    required this.viewModel,
    required this.profiles,
    required this.services,
    required this.agenda,
    required this.booking,
    required this.preferences,
  });

  final LoginViewModel viewModel;
  final ProfileRepository profiles;
  final BarberServiceRepository services;
  final AgendaRepository agenda;
  final BookingRepository booking;
  final AppPreferences preferences;
  @override
  State<BarberApp> createState() => _BarberAppState();
}

class _BarberAppState extends State<BarberApp> {
  final _google = GoogleTokenProvider();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.viewModel.initialize();
    });
  }

  @override
  void dispose() {
    widget.viewModel.dispose();
    widget.preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.preferences,
    builder: (context, _) => MaterialApp(
      locale: widget.preferences.language.locale,
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      title: 'Barber App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.preferences.themeMode,
      home: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final state = widget.viewModel.state;
          if (!state.isAuthenticated) {
            return LoginRoute(
              viewModel: widget.viewModel,
              getGoogleToken: _google.call,
            );
          }
          return AppShell(
            profiles: widget.profiles,
            services: widget.services,
            agenda: widget.agenda,
            booking: widget.booking,
            preferences: widget.preferences,
            onLogout: widget.viewModel.onLogout,
            loggingOut: state.isLoading,
            logoutError: state.error,
          );
        },
      ),
    ),
  );
}
