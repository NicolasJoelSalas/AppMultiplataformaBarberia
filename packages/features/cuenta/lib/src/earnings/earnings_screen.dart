import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../format_ars.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({
    super.key,
    required this.appointments,
    required this.error,
    required this.onRetry,
  });

  final List<Appointment>? appointments;
  final BookingFailure? error;
  final VoidCallback onRetry;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final _calendar = AgendaCalendar(EarningsReport.zoneId);
  late final AppLifecycleListener _lifecycle;
  EarningsPeriod _period = EarningsPeriod.week;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => setState(() {}));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _monthly => _period == EarningsPeriod.month;

  String _text(String es, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : es;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appointments = widget.appointments;
    final report = const CalculateEarningsReport()(
      appointments ?? const [],
      now: DateTime.now(),
      period: _period,
      offset: _offset,
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_text('Ganancias', 'Earnings')),
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _text('Reporte de ganancias', 'Earnings report'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                'Consultá tus ingresos y servicios realizados.',
                'Review your earnings and completed services.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<EarningsPeriod>(
              segments: [
                ButtonSegment(
                  value: EarningsPeriod.week,
                  label: Text(_text('Semanal', 'Weekly')),
                ),
                ButtonSegment(
                  value: EarningsPeriod.month,
                  label: Text(_text('Mensual', 'Monthly')),
                ),
              ],
              selected: {_period},
              onSelectionChanged: (selected) => setState(() {
                _period = selected.single;
                _offset = 0;
              }),
            ),
            const SizedBox(height: 12),
            _periodPicker(report),
            const SizedBox(height: 20),
            if (widget.error case final error?) ...[
              Text(_syncMessage(error), style: TextStyle(color: colors.error)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: widget.onRetry,
                  child: Text(_text('Reintentar', 'Try again')),
                ),
              ),
            ] else if (appointments == null)
              const Center(child: CircularProgressIndicator()),
            if (appointments != null) ...[
              _summary(report),
              const SizedBox(height: 12),
              Text(
                _text(
                  'El total suma los importes registrados de servicios realizados según la fecha del turno.',
                  'The total includes recorded charges for completed services based on the appointment date.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (report.missingAmount > 0) ...[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _text(
                        'Turnos sin importe registrado: ${report.missingAmount}. El total es parcial.',
                        'Appointments without a recorded amount: ${report.missingAmount}. The total is partial.',
                      ),
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                _text('Detalle de servicios', 'Service details'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _details(report),
            ],
          ],
        ),
      ),
    );
  }

  Widget _periodPicker(EarningsReport report) {
    final material = MaterialLocalizations.of(context);
    final title = _monthly
        ? material.formatMonthYear(report.from)
        : _text(
            'Semana del ${material.formatShortMonthDay(report.from)}',
            'Week of ${material.formatShortMonthDay(report.from)}',
          );
    final current = _offset == 0;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: [
          IconButton(
            tooltip: _monthly
                ? _text('Mes anterior', 'Previous month')
                : _text('Semana anterior', 'Previous week'),
            onPressed: () => setState(() => _offset--),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: current ? null : () => setState(() => _offset = 0),
                  child: Text(
                    current
                        ? _text('Período actual', 'Current period')
                        : _monthly
                        ? _text('Volver a este mes', 'Back to this month')
                        : _text('Volver a esta semana', 'Back to this week'),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _monthly
                ? _text('Mes siguiente', 'Next month')
                : _text('Semana siguiente', 'Next week'),
            onPressed: current ? null : () => setState(() => _offset++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _summary(EarningsReport report) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final material = MaterialLocalizations.of(context);
    final from = material.formatShortDate(report.from);
    final through = material.formatShortDate(report.through);
    final count = report.completed.length;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.onPrimaryContainer),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                spacing: 8,
                children: [
                  Icon(
                    _monthly
                        ? Icons.calendar_month_outlined
                        : Icons.date_range_outlined,
                    size: 20,
                    color: colors.onPrimaryContainer,
                  ),
                  Flexible(
                    child: Text(
                      _monthly
                          ? _text('Ingresos del mes', 'Monthly earnings')
                          : _text('Ingresos de la semana', 'Weekly earnings'),
                    ),
                  ),
                ],
              ),
              Text(
                formatArs(context, report.totalCents),
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(_text('Pesos argentinos (ARS)', 'Argentine pesos (ARS)')),
              Divider(color: colors.onPrimaryContainer.withValues(alpha: .2)),
              Text(
                _text(
                  'Servicios realizados: $count',
                  'Completed services: $count',
                ),
              ),
              Text(_text('$from al $through', '$from to $through')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _details(EarningsReport report) {
    final colors = Theme.of(context).colorScheme;
    final rows = report.completed;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainer,
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                spacing: 10,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 32,
                    color: colors.primary,
                  ),
                  Text(
                    _text('Sin servicios realizados', 'No completed services'),
                  ),
                  Text(
                    _text(
                      'Los servicios que marques como realizados aparecerán en el período correspondiente.',
                      'Appointments marked completed will appear in their corresponding period.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in rows)
                  if ((item.chargedPriceCents ?? -1) >= 0) _serviceRow(item),
                if (report.missingAmount > 0) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      _text(
                        'Turnos sin importe',
                        'Appointments without an amount',
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final item in rows)
                    if ((item.chargedPriceCents ?? -1) < 0) _serviceRow(item),
                ],
              ],
            ),
    );
  }

  Widget _serviceRow(Appointment item) {
    final start = item.start!;
    final material = MaterialLocalizations.of(context);
    final minute = _calendar.minuteOfDay(start);
    final date = material.formatShortMonthDay(_calendar.dateOf(start));
    final time = material.formatTimeOfDay(
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      alwaysUse24HourFormat: true,
    );
    final cents = item.chargedPriceCents;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                item.participantName.trim().isEmpty
                    ? _text('Cliente sin nombre', 'Unnamed client')
                    : item.participantName,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                item.serviceName.trim().isEmpty
                    ? _text('Servicio sin asignar', 'Service unavailable')
                    : item.serviceName,
              ),
              Wrap(
                spacing: 12,
                children: [
                  Text('$date · $time'),
                  Text(
                    cents == null || cents < 0
                        ? _text('Sin importe', 'No amount')
                        : formatArs(context, cents),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  String _syncMessage(BookingFailure failure) {
    final detail = switch (failure) {
      BookingFailure.network => _text(
        'Revisá tu conexión a Internet.',
        'Check your internet connection.',
      ),
      BookingFailure.permission => _text(
        'Tu cuenta no tiene acceso a los turnos.',
        'Your account does not have access to appointments.',
      ),
      _ => _text(
        'No se pudieron actualizar los turnos.',
        'Could not refresh appointments.',
      ),
    };
    return widget.appointments == null
        ? detail
        : _text(
            'Mostrando los últimos turnos recibidos. $detail',
            'Showing the last received appointments. $detail',
          );
  }
}
