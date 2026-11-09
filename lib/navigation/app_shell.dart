import 'package:core_ui/core_ui.dart';
import 'package:domain/domain.dart';
import 'package:feature_cuenta/feature_cuenta.dart';
import 'package:feature_turnos/feature_turnos.dart';
import 'package:flutter/material.dart';

import '../app_preferences.dart';

enum _Tab {
  home('Inicio', 'Home', Icons.home_outlined, Icons.home),
  work('Trabajos', 'Work', Icons.collections_outlined, Icons.collections),
  appointments(
    'Turnos',
    'Appointments',
    Icons.date_range_outlined,
    Icons.date_range,
  ),
  schedule('Agenda', 'Schedule', Icons.event_note_outlined, Icons.event_note),
  account('Mi cuenta', 'My account', Icons.person_outline, Icons.person);

  const _Tab(this.es, this.en, this.icon, this.selectedIcon);

  final String es;
  final String en;
  final IconData icon;
  final IconData selectedIcon;

  String label(bool english) => english ? en : es;
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.profiles,
    required this.services,
    required this.agenda,
    required this.booking,
    required this.bookingPhotos,
    required this.preferences,
    required this.onLogout,
    required this.loggingOut,
    required this.logoutError,
  });

  final ProfileRepository profiles;
  final BarberServiceRepository services;
  final AgendaRepository agenda;
  final BookingRepository booking;
  final BookingPhotoRepository bookingPhotos;
  final AppPreferences preferences;
  final VoidCallback onLogout;
  final bool loggingOut;
  final AuthError? logoutError;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final MiCuentaViewModel _account;
  AppointmentsViewModel? _appointments;
  final _agendaKey = GlobalKey<AgendaScreenState>();
  _Tab _tab = _Tab.home;
  bool _editing = false;
  bool _agendaOpened = false;
  bool _appointmentsOpened = false;

  @override
  void initState() {
    super.initState();
    _account = MiCuentaViewModel(
      loadProfile: LoadProfileUseCase(widget.profiles),
      updateName: UpdateProfileNameUseCase(widget.profiles),
    );
    _account.addListener(_syncAppointments);
    _account.load();
  }

  void _syncAppointments() {
    final role = _account.profile?.role;
    if (role == null || _appointments?.role == role) return;
    _appointments?.dispose();
    final model = AppointmentsViewModel(widget.booking, role);
    _appointments = model;
    if (role == AccountRole.barber || _appointmentsOpened) model.start();
  }

  @override
  void dispose() {
    _account.removeListener(_syncAppointments);
    _account.dispose();
    _appointments?.dispose();
    super.dispose();
  }

  bool get _english => Localizations.localeOf(context).languageCode == 'en';
  String _text(String es, String en) => _english ? en : es;

  void _edit(bool editing) {
    setState(() => _editing = editing);
    _account.clearError();
  }

  void _goHome() => setState(() => _tab = _Tab.home);

  Widget _destinationIcon(_Tab tab, IconData icon) {
    final model = _appointments;
    final count = model?.pendingCount ?? 0;
    if (tab != _Tab.appointments ||
        model?.role != AccountRole.barber ||
        count == 0) {
      return Icon(icon);
    }
    final label = count == 1
        ? _text('1 turno pendiente', '1 pending appointment')
        : _text('$count turnos pendientes', '$count pending appointments');
    return Badge(
      label: Text('$count', semanticsLabel: label),
      child: Icon(icon),
    );
  }

  Future<int?> _reserve(AccountProfile profile, {Appointment? original}) async {
    final offset = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          repository: widget.booking,
          photos: widget.bookingPhotos,
          initialName: profile.name,
          original: original,
        ),
      ),
    );
    if (mounted && offset != null && profile.name.trim().isEmpty) {
      _account.load();
    }
    return offset;
  }

  void _openPending(String title) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _PendingScreen(title: title)),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _account,
    builder: (context, _) {
      if (widget.loggingOut || (_account.loading && _account.profile == null)) {
        return _status(
          widget.loggingOut
              ? _text('Cerrando sesión…', 'Signing out…')
              : _text('Cargando tu perfil…', 'Loading your profile…'),
          loading: true,
        );
      }
      final profile = _account.profile;
      final logoutError = widget.logoutError;
      if (profile == null) {
        return _status(
          authErrorMessage(
            logoutError ?? _account.error ?? AuthError.profileLoad,
            english: _english,
          ),
        );
      }
      final barber = profile.role == AccountRole.barber;
      final tabs = barber
          ? _Tab.values
          : const [_Tab.home, _Tab.appointments, _Tab.account];
      final activeTab = tabs.contains(_tab) ? _tab : _Tab.home;
      final index = tabs.indexOf(activeTab);
      return PopScope(
        canPop: activeTab == _Tab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || _account.saving) return;
          if (activeTab == _Tab.account && _editing) {
            _edit(false);
          } else if (activeTab == _Tab.schedule) {
            _agendaKey.currentState?.requestBack();
          } else {
            _goHome();
          }
        },
        child: Scaffold(
          body: IndexedStack(
            index: index,
            children: [
              for (final tab in tabs)
                TickerMode(
                  key: ValueKey(tab),
                  enabled: tab == activeTab,
                  child: tab == _Tab.account
                      ? MiCuentaScreen(
                          profile: profile,
                          editing: _editing,
                          onEditingChanged: _edit,
                          darkTheme:
                              Theme.of(context).brightness == Brightness.dark,
                          onDarkThemeChanged: widget.preferences.setDarkTheme,
                          language: widget.preferences.language,
                          onLanguageChanged: widget.preferences.setLanguage,
                          onSave: _account.save,
                          saving: _account.saving,
                          error: switch (logoutError ?? _account.error) {
                            final error? => authErrorMessage(
                              error,
                              english: _english,
                            ),
                            null => null,
                          },
                          onLogout: _account.saving ? null : widget.onLogout,
                          onServices: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ServiciosScreen(repository: widget.services),
                            ),
                          ),
                          onLocation: () => _openPending(
                            _text(
                              'Ubicación de la barbería',
                              'Barbershop location',
                            ),
                          ),
                        )
                      : tab == _Tab.schedule
                      ? _agendaOpened
                            ? AgendaScreen(
                                key: _agendaKey,
                                repository: widget.agenda,
                                onBack: _goHome,
                              )
                            : const SizedBox.shrink()
                      : tab == _Tab.appointments
                      ? _appointmentsOpened
                            ? AppointmentsScreen(
                                model: _appointments!,
                                onReserve: barber
                                    ? null
                                    : () => _reserve(profile),
                                onEdit: barber
                                    ? null
                                    : (item) =>
                                          _reserve(profile, original: item),
                              )
                            : const SizedBox.shrink()
                      : tab == _Tab.home && barber
                      ? ListenableBuilder(
                          listenable: _appointments!,
                          builder: (context, _) => EarningsScreen(
                            appointments: _appointments!.appointments,
                            error: _appointments!.error,
                            onRetry: _appointments!.retry,
                          ),
                        )
                      : _PendingScreen(
                          title: tab.label(_english),
                          description: tab == _Tab.home
                              ? _text(
                                  'Publicaciones de trabajos',
                                  'Barbershop posts',
                                )
                              : null,
                        ),
                ),
            ],
          ),
          bottomNavigationBar: ListenableBuilder(
            listenable: _appointments!,
            builder: (context, _) => NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (index) {
                if (_account.saving ||
                    _agendaKey.currentState?.saving == true) {
                  return;
                }
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() {
                  _tab = tabs[index];
                  if (_tab == _Tab.schedule) _agendaOpened = true;
                  if (_tab == _Tab.appointments) {
                    _appointmentsOpened = true;
                    _appointments!.start();
                  }
                });
              },
              destinations: [
                for (final tab in tabs)
                  NavigationDestination(
                    icon: _destinationIcon(tab, tab.icon),
                    selectedIcon: _destinationIcon(tab, tab.selectedIcon),
                    label: tab.label(_english),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _status(String message, {bool loading = false}) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ],
            Text(message, textAlign: TextAlign.center),
            if (!loading) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _account.load,
                child: Text(_text('Reintentar', 'Try again')),
              ),
              TextButton(
                onPressed: widget.onLogout,
                child: Text(_text('Cerrar sesión', 'Sign out')),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PendingScreen extends StatelessWidget {
  const _PendingScreen({required this.title, this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description case final label?) ...[
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              Text(english ? 'Migration pending' : 'Pendiente de migración'),
            ],
          ),
        ),
      ),
    );
  }
}
