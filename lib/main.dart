import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'di/auth_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    final viewModel = await AuthDependencies.create();
    runApp(BarberApp(viewModel: viewModel));
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
  const BarberApp({super.key, required this.viewModel});
  final LoginViewModel viewModel;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('es'),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    title: 'Barber App',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
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
        // Replace with the authenticated shell when the remaining features migrate.
        return Scaffold(
          appBar: AppBar(title: const Text('Barber App')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, size: 48),
                const SizedBox(height: 16),
                const Text('Sesión iniciada correctamente'),
                if (state.error != null) Text(authErrorMessage(state.error!)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: state.isLoading ? null : widget.viewModel.onLogout,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
