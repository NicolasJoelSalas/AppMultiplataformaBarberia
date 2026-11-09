import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'booking_strings.dart';
import 'reference_photo.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    super.key,
    required this.repository,
    required this.role,
    this.onReserve,
    this.onEdit,
  });

  final BookingRepository repository;
  final AccountRole role;
  final Future<int?> Function()? onReserve;
  final Future<int?> Function(Appointment)? onEdit;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Stream<List<Appointment>> _appointments = _watch();
  int _offset = 0;
  bool _canceling = false;

  Stream<List<Appointment>> _watch() =>
      widget.repository.watchAppointments(widget.role);

  @override
  void didUpdateWidget(covariant AppointmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role ||
        oldWidget.repository != widget.repository) {
      _appointments = _watch();
    }
  }

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
    if (_canceling) return;
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
    if (!mounted || confirmed != true || _canceling) return;
    setState(() => _canceling = true);
    try {
      await widget.repository.cancel(item.id);
      if (mounted) _message(strings.canceled);
    } on BookingFailure catch (failure) {
      if (mounted) _message(strings.error(failure));
    } catch (_) {
      if (mounted) _message(strings.error(BookingFailure.operation));
    } finally {
      if (mounted) setState(() => _canceling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = BookingStrings(context);
    final colors = Theme.of(context).colorScheme;
    final barber = widget.role == AccountRole.barber;
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
                onPressed: _canceling ? null : _reserve,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.add),
                label: Text(strings.reserve),
              ),
            ),
      body: SafeArea(
        top: false,
        child: StreamBuilder(
          stream: _appointments,
          builder: (context, snapshot) {
            final now = DateTime.now();
            final filtered = [
              for (final item in snapshot.data ?? const <Appointment>[])
                if (_inWeek(item, now)) item,
            ]..sort((a, b) => a.start!.compareTo(b.start!));
            return ListView(
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
                if (snapshot.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    strings.error(switch (snapshot.error) {
                      final BookingFailure failure => failure,
                      _ => BookingFailure.operation,
                    }),
                    style: TextStyle(color: colors.error),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => setState(() => _appointments = _watch()),
                      child: Text(strings.retry),
                    ),
                  ),
                ] else if (!snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  )
                else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(strings.noAppointments),
                  ),
                for (final item in filtered) _card(item, strings, barber, now),
              ],
            );
          },
        ),
      ),
    );
  }

  AgendaCalendar _calendar(Appointment item) {
    const fallback = 'America/Argentina/Buenos_Aires';
    try {
      return AgendaCalendar(item.zoneId ?? fallback);
    } on AgendaProblem {
      return AgendaCalendar(fallback);
    }
  }

  bool _inWeek(Appointment item, DateTime now) {
    final start = item.start;
    if (start == null) return false;
    final calendar = _calendar(item);
    final monday = calendar.mondayFor(now, _offset);
    final date = calendar.dateOf(start);
    return !date.isBefore(monday) &&
        date.isBefore(monday.add(const Duration(days: 7)));
  }

  Widget _card(
    Appointment item,
    BookingStrings strings,
    bool barber,
    DateTime now,
  ) {
    final start = item.start!;
    final end = item.end;
    final calendar = _calendar(item);
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
            if (end != null) Text(strings.interval(calendar, start, end)),
            Text(
              strings.status(item.status),
              style: TextStyle(
                color: item.status == AppointmentStatus.canceled
                    ? colors.error
                    : colors.primary,
              ),
            ),
            if (item.referenceUrl case final url?) ...[
              Text(strings.photo),
              ReferencePhoto(url: url),
            ],
            if (item.canChangeAt(now))
              Wrap(
                spacing: 8,
                children: [
                  if (!barber && widget.onEdit != null)
                    OutlinedButton(
                      onPressed: _canceling ? null : () => _reserve(item),
                      child: Text(strings.edit),
                    ),
                  TextButton(
                    onPressed: _canceling ? null : () => _cancel(item),
                    child: Text(strings.cancelAppointment),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
