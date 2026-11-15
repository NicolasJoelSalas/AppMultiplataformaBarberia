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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _filters(report),
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
              const SizedBox(height: 24),
              _details(report),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filters(EarningsReport report) => LayoutBuilder(
    builder: (context, constraints) {
      final segments = SegmentedButton<EarningsPeriod>(
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
      );
      final period = _periodPicker(report);
      if (constraints.maxWidth >= 640) {
        return Row(
          spacing: 16,
          children: [
            segments,
            Expanded(child: period),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [segments, period],
      );
    },
  );

  Widget _periodPicker(EarningsReport report) {
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    final from = report.from.year == report.through.year
        ? material.formatShortMonthDay(report.from)
        : material.formatShortDate(report.from);
    final through = material.formatShortMonthDay(report.through);
    final year = material.formatYear(report.through);
    final current = _offset == 0;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
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
                Padding(
                  padding: EdgeInsets.symmetric(vertical: current ? 8 : 0),
                  child: Text(
                    _monthly
                        ? material.formatMonthYear(report.from)
                        : '$from – $through $year',
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!current)
                  TextButton(
                    onPressed: () => setState(() => _offset = 0),
                    child: Text(
                      _monthly
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
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(
              report.missingAmount == 0
                  ? _text('Total cobrado', 'Total collected')
                  : _text('Total parcial', 'Partial total'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            Text(
              formatArs(context, report.totalCents),
              style: theme.textTheme.headlineLarge?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (report.missingAmount > 0)
              Text(
                report.missingAmount == 1
                    ? _text(
                        '1 servicio sin importe',
                        '1 service without an amount',
                      )
                    : _text(
                        '${report.missingAmount} servicios sin importe',
                        '${report.missingAmount} services without an amount',
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _details(EarningsReport report) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final material = MaterialLocalizations.of(context);
    final days = <DateTime, List<Appointment>>{};
    for (final item in report.completed) {
      final date = _calendar.dateOf(item.start!);
      (days[date] ??= []).add(item);
    }
    final count = report.completed.length;
    if (count == 0) {
      return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colors.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            spacing: 12,
            children: [
              Icon(Icons.receipt_long_outlined, color: colors.onSurfaceVariant),
              Expanded(
                child: Text(
                  _text(
                    'Sin servicios realizados en este período',
                    'No completed services in this period',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Row(
            spacing: 12,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  count == 1
                      ? _text('1 servicio realizado', '1 completed service')
                      : _text(
                          '$count servicios realizados',
                          '$count completed services',
                        ),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        for (final day in days.entries)
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: colors.surfaceContainer,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        spacing: 8,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                          Expanded(
                            child: Text(
                              material.formatMediumDate(day.key),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                for (final (index, item) in day.value.indexed) ...[
                  if (index > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _serviceRow(item),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _serviceRow(Appointment item) {
    final minute = _calendar.minuteOfDay(item.start!);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      alwaysUse24HourFormat: true,
    );
    final cents = item.chargedPriceCents;
    final hasAmount = cents != null && cents >= 0;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final client = item.participantName.trim().isEmpty
        ? _text('Cliente sin nombre', 'Unnamed client')
        : item.participantName;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          item.serviceName.trim().isEmpty
              ? _text('Servicio sin asignar', 'Service unavailable')
              : item.serviceName,
          style: theme.textTheme.titleSmall,
        ),
        Text(
          '$client · $time',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
    final amount = Text(
      hasAmount ? formatArs(context, cents) : _text('Sin importe', 'No amount'),
      style: theme.textTheme.labelLarge?.copyWith(
        color: hasAmount ? colors.primary : colors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 250 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [details, amount],
            );
          }
          return Row(
            spacing: 16,
            children: [
              Expanded(flex: 3, child: details),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: amount,
                ),
              ),
            ],
          );
        },
      ),
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
