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
    this.onEnableAlerts,
    this.disabledReminders,
    this.onReminderChanged,
  });

  final AppointmentsViewModel model;
  final Future<int?> Function()? onReserve;
  final Future<int?> Function(Appointment)? onEdit;
  final ValueChanged<String>? onDirections;
  final VoidCallback? onEnableAlerts;
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
        actions: [
          if (widget.onEnableAlerts case final enable?)
            IconButton(
              onPressed: enable,
              tooltip: Localizations.localeOf(context).languageCode == 'en'
                  ? 'Enable appointment alerts'
                  : 'Activar avisos de turnos',
              icon: const Icon(Icons.notifications_outlined),
            ),
        ],
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
            Wrap(
              spacing: 8,
              children: [
                for (final filter in const [
                  null,
                  AppointmentStatus.pending,
                  AppointmentStatus.canceled,
                  AppointmentStatus.completed,
                ])
                  ChoiceChip(
                    label: Text(strings.filter(filter)),
                    selected: _statusFilter == filter,
                    onSelected: (_) => setState(() => _statusFilter = filter),
                  ),
              ],
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
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.serviceName.isEmpty
                  ? strings.unknownService
                  : item.serviceName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${barber ? strings.client : strings.barber} · ${item.participantName.isEmpty ? strings.unknownName : item.participantName}',
            ),
            Text(strings.date(calendar.dateOf(start))),
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
            if (end != null) Text(strings.interval(calendar, start, end)),
            Text(
              strings.status(item.status),
              style: TextStyle(
                color: item.status == AppointmentStatus.canceled
                    ? colors.error
                    : colors.primary,
              ),
            ),
            if (item.chargedPriceCents case final cents? when barber)
              Text(strings.charged(cents)),
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
                  TextButton(
                    onPressed: _busy ? null : () => _cancel(item),
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
}
