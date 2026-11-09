import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'booking_strings.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    super.key,
    required this.repository,
    required this.role,
    this.onReserve,
  });

  final BookingRepository repository;
  final AccountRole role;
  final Future<int?> Function()? onReserve;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Stream<List<Appointment>> _appointments = _watch();
  int _offset = 0;

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

  Future<void> _reserve() async {
    final offset = await widget.onReserve?.call();
    if (!mounted || offset == null) return;
    setState(() => _offset = offset);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(BookingStrings(context).booked)));
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
                onPressed: _reserve,
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
                for (final item in filtered) _card(item, strings, barber),
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

  Widget _card(Appointment item, BookingStrings strings, bool barber) {
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
          ],
        ),
      ),
    );
  }
}
