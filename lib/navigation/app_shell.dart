import 'package:core_ui/core_ui.dart';
import 'package:domain/domain.dart';
import 'package:feature_cuenta/feature_cuenta.dart';
import 'package:feature_turnos/feature_turnos.dart';
import 'package:feature_trabajos/feature_trabajos.dart';
import 'package:flutter/material.dart';

import '../app_preferences.dart';
import '../notifications/appointment_alerts.dart';

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
    required this.work,
    required this.locations,
    required this.deviceLocation,
    required this.routes,
    required this.preferences,
    required this.onLogout,
    required this.loggingOut,
    required this.logoutError,
    this.alerts,
  });

  final ProfileRepository profiles;
  final BarberServiceRepository services;
  final AgendaRepository agenda;
  final BookingRepository booking;
  final BookingPhotoRepository bookingPhotos;
  final WorkRepository work;
  final ShopLocationRepository locations;
  final DeviceLocationRepository deviceLocation;
  final ShopRouteRepository routes;
  final AppPreferences preferences;
  final Future<void> Function() onLogout;
  final bool loggingOut;
  final AuthError? logoutError;
  final AppointmentAlerts? alerts;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late final MiCuentaViewModel _account;
  AppointmentsViewModel? _appointments;
  final _agendaKey = GlobalKey<AgendaScreenState>();
  _Tab _tab = _Tab.home;
  bool _editing = false;
  bool _agendaOpened = false;
  bool _appointmentsOpened = false;
  bool _closingSession = false;

  @override
  void initState() {
    super.initState();
    _account = MiCuentaViewModel(
      loadProfile: LoadProfileUseCase(widget.profiles),
      updateName: UpdateProfileNameUseCase(widget.profiles),
    );
    WidgetsBinding.instance.addObserver(this);
    widget.alerts?.addListener(_handleAlerts);
    _account.addListener(_syncAppointments);
    _account.load();
  }

  void _syncAppointments() {
    final role = _account.profile?.role;
    if (role == null || _appointments?.role == role) return;
    _appointments?.dispose();
    final model = AppointmentsViewModel(widget.booking, role);
    _appointments = model;
    model.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startAlerts();
      _handleAlerts();
    });
  }

  void _startAlerts() {
    final role = _account.profile?.role;
    if (role != null && !_closingSession) {
      widget.alerts?.start(role, english: _english);
    }
  }

  void _handleAlerts() {
    final alerts = widget.alerts;
    if (_account.profile == null || _closingSession || alerts == null) return;
    if (alerts.takeTap()) _openAppointments();
    for (final notice in alerts.takeNotices()) {
      final message = appointmentNoticeSummary(notice, _english);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: _text('Ver turnos', 'View appointments'),
            onPressed: _openAppointments,
          ),
        ),
      );
    }
  }

  void _openAppointments() {
    if (!mounted || _closingSession) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _tab = _Tab.appointments;
      _appointmentsOpened = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startAlerts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_closingSession) {
      widget.alerts?.refresh();
    }
  }

  Future<void> _logout() async {
    if (_closingSession) return;
    setState(() => _closingSession = true);
    ScaffoldMessenger.of(context).clearSnackBars();
    try {
      await widget.alerts?.stop();
      await widget.onLogout();
    } finally {
      if (mounted) {
        setState(() => _closingSession = false);
        _startAlerts();
      }
    }
  }

  Future<void> _enableAlerts(bool client) async {
    final allowed = await widget.alerts!.requestPermissions(exact: client);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allowed
              ? _text(
                  'Permisos de avisos habilitados.',
                  'Notification permissions enabled.',
                )
              : _text(
                  'Revisá los permisos de notificaciones y alarmas en Ajustes.',
                  'Check notification and alarm permissions in Settings.',
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.alerts?.removeListener(_handleAlerts);
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

  Future<int?> _reserve(
    AccountProfile profile, {
    Appointment? original,
    String? barberId,
  }) async {
    final offset = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          repository: widget.booking,
          photos: widget.bookingPhotos,
          initialName: profile.name,
          original: original,
          initialBarberId: barberId,
        ),
      ),
    );
    if (mounted && offset != null && profile.name.trim().isEmpty) {
      _account.load();
    }
    return offset;
  }

  void _openLocation([String? barberId]) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShopLocationScreen(
          locations: widget.locations,
          device: widget.deviceLocation,
          barberId: barberId,
          routes: widget.routes,
        ),
      ),
    );
  }

  Future<void> _reserveFromWork(AccountProfile profile, String barberId) async {
    final offset = await _reserve(profile, barberId: barberId);
    if (!mounted || offset == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_text('Turno reservado.', 'Appointment booked.'))),
    );
  }

  void _selectTab(_Tab tab) {
    if (_account.saving || _agendaKey.currentState?.saving == true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = tab;
      if (tab == _Tab.schedule) _agendaOpened = true;
      if (tab == _Tab.appointments) {
        _appointmentsOpened = true;
        _appointments!.start();
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _account,
    builder: (context, _) {
      if (_closingSession ||
          widget.loggingOut ||
          (_account.loading && _account.profile == null)) {
        return _status(
          _closingSession || widget.loggingOut
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
      final wide = MediaQuery.sizeOf(context).width >= 1000;
      final tabContent = IndexedStack(
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
                      onLogout: _account.saving ? null : _logout,
                      onServices: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              ServiciosScreen(repository: widget.services),
                        ),
                      ),
                      onLocation: _openLocation,
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
                            onDirections: barber ? null : _openLocation,
                            onEnableAlerts:
                                widget.alerts?.supportsSystemPermissions != true
                                ? null
                                : () => _enableAlerts(!barber),
                            onReserve: barber ? null : () => _reserve(profile),
                            onEdit: barber
                                ? null
                                : (item) => _reserve(profile, original: item),
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
                  : WorkScreen(
                      repository: widget.work,
                      title: tab.label(_english),
                      barber: barber,
                      onReserve: (id) => _reserveFromWork(profile, id),
                      onDirections: _openLocation,
                    ),
            ),
        ],
      );
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
          body: Row(
            children: [
              if (wide) ...[
                _desktopNavigation(tabs, index),
                const VerticalDivider(width: 1),
              ],
              Expanded(key: const ValueKey('tab-content'), child: tabContent),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : ListenableBuilder(
                  listenable: _appointments!,
                  builder: (context, _) => NavigationBar(
                    selectedIndex: index,
                    onDestinationSelected: (index) => _selectTab(tabs[index]),
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

  Widget _desktopNavigation(List<_Tab> tabs, int index) => ListenableBuilder(
    listenable: _appointments!,
    builder: (context, _) => NavigationRail(
      extended: true,
      scrollable: true,
      minExtendedWidth: 200,
      selectedIndex: index,
      onDestinationSelected: (index) => _selectTab(tabs[index]),
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Text(
          'Barber App',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      destinations: [
        for (final tab in tabs)
          NavigationRailDestination(
            icon: _destinationIcon(tab, tab.icon),
            selectedIcon: _destinationIcon(tab, tab.selectedIcon),
            label: Text(tab.label(_english)),
          ),
      ],
    ),
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
                onPressed: _logout,
                child: Text(_text('Cerrar sesión', 'Sign out')),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
