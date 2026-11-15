import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'appointments_view_model.dart';
import 'booking_strings.dart';
import 'reference_photo.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    super.key,
    required this.model,
    this.onReserve,
    this.onEdit,
    this.onDirections,
    this.disabledReminders,
    this.onReminderChanged,
  });

  final AppointmentsViewModel model;
  final Future<int?> Function()? onReserve;
  final Future<int?> Function(Appointment)? onEdit;
  final ValueChanged<String>? onDirections;
  final Set<String>? disabledReminders;
  final Future<void> Function(String appointmentId, bool enabled)?
  onReminderChanged;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _offset = 0;
  AppointmentStatus? _statusFilter;
  bool _savingReminder = false;
  bool get _busy =>
      widget.model.savingId != null ||
      widget.model.error == BookingFailure.network ||
      widget.model.error == BookingFailure.permission;

  Future<void> _reserve([Appointment? original]) async {
    final offset = await (original == null
        ? widget.onReserve?.call()
        : widget.onEdit?.call(original));
    if (!mounted || offset == null) return;
    setState(() => _offset = offset);
    final strings = BookingStrings(context);
    _message(original == null ? strings.booked : strings.edited);
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _cancel(Appointment item) async {
    if (_busy) return;
    final strings = BookingStrings(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.cancelAppointment),
        content: Text(strings.cancelMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.cancelAppointment),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _busy) return;
    await _perform(() => widget.model.cancel(item), strings.canceled);
  }

  Future<void> _toggleReminder(Appointment item, bool enabled) async {
    if (_savingReminder) return;
    setState(() => _savingReminder = true);
    try {
      await widget.onReminderChanged!(item.id, enabled);
    } catch (_) {
      if (mounted) {
        _message(BookingStrings(context).error(BookingFailure.operation));
      }
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  Future<void> _perform(Future<void> Function() action, String success) async {
    if (_busy) return;
    final strings = BookingStrings(context);
    try {
      await action();
      if (mounted) _message(success);
    } on BookingFailure catch (failure) {
      if (mounted) _message(strings.error(failure));
    } catch (_) {
      if (mounted) _message(strings.error(BookingFailure.operation));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) => _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    final strings = BookingStrings(context);
    final colors = Theme.of(context).colorScheme;
    final barber = widget.model.role == AccountRole.barber;
    final now = DateTime.now();
    final appointments = widget.model.appointments;
    final error = widget.model.error;
    final (weekly, groups) = widget.model.groupedWeek(
      now,
      _offset,
      _statusFilter,
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(barber ? strings.appointments : strings.myAppointments),
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
      bottomNavigationBar: barber || widget.onReserve == null
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _busy ? null : _reserve,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.add),
                label: Text(strings.reserve),
              ),
            ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final (offset, label) in [
                  strings.current,
                  strings.next,
                ].indexed)
                  ChoiceChip(
                    label: Text(label),
                    selected: _offset == offset,
                    onSelected: (selected) {
                      if (selected) setState(() => _offset = offset);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _AppointmentStatusFilter(
              strings: strings,
              value: _statusFilter,
              onChanged: (status) => setState(() => _statusFilter = status),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(strings.error(error), style: TextStyle(color: colors.error)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: widget.model.retry,
                  child: Text(strings.retry),
                ),
              ),
            ] else if (appointments == null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              )
            else if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  weekly.isEmpty
                      ? strings.noAppointments
                      : strings.noMatchingAppointments,
                ),
              ),
            for (final status in AppointmentStatus.values)
              if (groups[status] case final items?) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    header: true,
                    child: Text(
                      strings.section(status),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: colors.primary),
                    ),
                  ),
                ),
                for (final item in items) _card(item, strings, barber, now),
              ],
          ],
        ),
      ),
    );
  }

  Widget _card(
    Appointment item,
    BookingStrings strings,
    bool barber,
    DateTime now,
  ) {
    final start = item.start!;
    final end = item.end;
    final calendar = widget.model.calendarFor(item);
    final reminderDisabled =
        widget.disabledReminders?.contains(item.id) ?? false;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final participant = item.participantName.isEmpty
        ? strings.unknownName
        : item.participantName;
    return Card(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    item.serviceName.isEmpty
                        ? strings.unknownService
                        : item.serviceName,
                    style: theme.textTheme.titleLarge,
                  ),
                  _statusBadge(item.status, strings),
                ],
              ),
            ),
            _detail(
              Icons.person_outline,
              '${barber ? strings.client : strings.barber} · $participant',
              theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _detail(
                        Icons.calendar_today_outlined,
                        strings.date(calendar.dateOf(start)),
                        theme.textTheme.bodyMedium,
                      ),
                      if (end != null)
                        _detail(
                          Icons.schedule_outlined,
                          strings.interval(calendar, start, end),
                          theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (!barber &&
                item.barberId.isNotEmpty &&
                item.canChangeAt(now) &&
                widget.onDirections != null &&
                widget.model.error != BookingFailure.network)
              TextButton.icon(
                onPressed: () => widget.onDirections!(item.barberId),
                icon: const Icon(Icons.directions_outlined),
                label: Text(
                  Localizations.localeOf(context).languageCode == 'en'
                      ? 'Directions'
                      : 'Cómo llegar',
                ),
              ),
            if (item.chargedPriceCents case final cents? when barber)
              _detail(
                Icons.payments_outlined,
                strings.charged(cents),
                theme.textTheme.titleSmall?.copyWith(color: colors.primary),
              ),
            if (item.referenceUrl != null) ...[
              Text(strings.photo),
              ReferencePhoto(url: item.visibleReferenceUrl),
            ],
            if (item.canChangeAt(now))
              Wrap(
                spacing: 8,
                children: [
                  if (!barber && widget.onEdit != null)
                    OutlinedButton(
                      onPressed: _busy ? null : () => _reserve(item),
                      child: Text(strings.edit),
                    ),
                  if (!barber &&
                      widget.disabledReminders != null &&
                      widget.onReminderChanged != null)
                    OutlinedButton.icon(
                      onPressed: _savingReminder
                          ? null
                          : () => _toggleReminder(item, reminderDisabled),
                      icon: Icon(
                        reminderDisabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                      ),
                      label: Text(
                        reminderDisabled
                            ? (english
                                  ? 'Enable reminders'
                                  : 'Activar recordatorios')
                            : (english
                                  ? 'Disable reminders'
                                  : 'Desactivar recordatorios'),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _cancel(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(
                        color: _busy
                            ? colors.error.withValues(alpha: .38)
                            : colors.error,
                      ),
                    ),
                    child: Text(strings.cancelAppointment),
                  ),
                ],
              ),
            if (barber && item.status == AppointmentStatus.pending) ...[
              FilledButton.icon(
                onPressed: !_busy && item.canCompleteAt(now)
                    ? () => _perform(
                        () => widget.model.complete(item),
                        strings.completed,
                      )
                    : null,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  widget.model.savingId == item.id
                      ? strings.saving
                      : strings.complete,
                ),
              ),
              if (!item.canCompleteAt(now))
                Text(
                  strings.completeFromStart,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text, TextStyle? style) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      Icon(icon, size: 16, color: style?.color),
      Flexible(child: Text(text, style: style)),
    ],
  );

  Widget _statusBadge(AppointmentStatus status, BookingStrings strings) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, background, foreground) = switch (status) {
      AppointmentStatus.pending => (
        Icons.schedule_outlined,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      AppointmentStatus.canceled => (
        Icons.cancel_outlined,
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      AppointmentStatus.completed => (
        Icons.check_circle_outline,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      AppointmentStatus.other => (
        Icons.info_outline,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: _detail(
          icon,
          strings.status(status),
          theme.textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AppointmentStatusFilter extends StatelessWidget {
  const _AppointmentStatusFilter({
    required this.strings,
    required this.value,
    required this.onChanged,
  });

  static const _options = <(AppointmentStatus?, IconData)>[
    (null, Icons.list_alt_outlined),
    (AppointmentStatus.pending, Icons.schedule_outlined),
    (AppointmentStatus.canceled, Icons.cancel_outlined),
    (AppointmentStatus.completed, Icons.check_circle_outline),
  ];

  final BookingStrings strings;
  final AppointmentStatus? value;
  final ValueChanged<AppointmentStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    const gap = 6.0;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(gap),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScaler = MediaQuery.textScalerOf(context);
                final columns =
                    constraints.maxWidth >= 544 && textScaler.scale(14) <= 18
                    ? 4
                    : 2;
                return Column(
                  spacing: gap,
                  children: [
                    for (
                      var start = 0;
                      start < _options.length;
                      start += columns
                    )
                      Row(
                        spacing: gap,
                        children: [
                          for (final (status, icon)
                              in _options.skip(start).take(columns))
                            Expanded(child: _option(colors, status, icon)),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(ColorScheme colors, AppointmentStatus? status, IconData icon) {
    final selected = status == value;
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: () => onChanged(status),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          backgroundColor: selected ? colors.primaryContainer : null,
          foregroundColor: selected
              ? colors.onPrimaryContainer
              : colors.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 6,
          children: [
            Icon(icon, size: 18),
            Flexible(
              child: Text(
                strings.filter(status),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
