import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'agenda_strings.dart';
import 'agenda_view_model.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({
    super.key,
    required this.repository,
    required this.onBack,
  });

  final AgendaRepository repository;
  final VoidCallback onBack;

  @override
  State<AgendaScreen> createState() => AgendaScreenState();
}

class AgendaScreenState extends State<AgendaScreen> {
  late final AgendaViewModel _model;
  final _scroll = ScrollController();

  bool get saving => _model.saving;

  @override
  void initState() {
    super.initState();
    _model = AgendaViewModel(widget.repository)..load();
  }

  @override
  void dispose() {
    _model.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> requestBack() async {
    if (_model.saving) return;
    final strings = AgendaStrings(context);
    if (_model.hasChanges) {
      if (!await _confirm(strings.leave, strings) || !mounted) return;
      _model.discardChanges();
    }
    if (mounted) widget.onBack();
  }

  Future<void> _reload() async {
    final strings = AgendaStrings(context);
    if (_model.selectedHasChanges &&
        !await _confirm(strings.discard, strings)) {
      return;
    }
    if (mounted) await _model.load();
  }

  Future<bool> _confirm(String label, AgendaStrings strings) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(label),
          content: Text(strings.unsaved),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.keepEditing),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(label),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _save() async {
    await _model.save();
    if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _pick(
    int index,
    int span, {
    required bool start,
    required String value,
  }) async {
    final minute = AgendaSpan.minutes(value) ?? (start ? 9 : 18) * 60;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || time == null) return;
    final hour = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    _model.setTime(index, span, start: start, value: '$hour:$minutes');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AgendaStrings(context);
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final week = _model.week;
        final problem = _model.problem;
        final publication = _model.publication;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const BackButtonIcon(),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: _model.saving ? null : requestBack,
            ),
            title: Text(strings.title),
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
          ),
          bottomNavigationBar: week == null
              ? null
              : SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: FilledButton.icon(
                    onPressed: _model.busy ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _model.saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_available_outlined),
                    label: Text(_model.saving ? strings.saving : strings.save),
                  ),
                ),
          body: SafeArea(
            top: false,
            child: ListView(
              controller: _scroll,
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
                        selected: _model.offset == offset,
                        onSelected: _model.busy
                            ? null
                            : (selected) {
                                if (!selected) return;
                                if (_scroll.hasClients) _scroll.jumpTo(0);
                                _model.select(offset);
                              },
                      ),
                  ],
                ),
                if (week != null) ...[
                  const SizedBox(height: 12),
                  _weekInfo(week, strings),
                ],
                if (_model.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (publication != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    switch (publication.spanCount) {
                      final count? => strings.published(count),
                      null => strings.pending,
                    },
                    style: TextStyle(
                      color: publication.problem == null
                          ? colors.primary
                          : colors.error,
                    ),
                  ),
                ],
                if (problem != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    problem.day == null
                        ? strings.error(problem)
                        : '${strings.day(problem.day!)} · ${strings.error(problem)}',
                    style: TextStyle(color: colors.error),
                  ),
                  if (!_model.busy &&
                      (week == null ||
                          problem.reason == AgendaFailure.weekChanged ||
                          problem.reason == AgendaFailure.changed))
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton(
                        onPressed: _reload,
                        child: Text(
                          week == null ? strings.retry : strings.reload,
                        ),
                      ),
                    ),
                ],
                if (week != null)
                  for (final (index, day) in week.days.indexed)
                    _dayCard(week, day, index, strings),
              ],
            ),
          ),
        );
      },
    );
  }

  String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Widget _weekInfo(AgendaWeek week, AgendaStrings strings) {
    final colors = Theme.of(context).colorScheme;
    final today = AgendaCalendar(week.zoneId).dateOf(DateTime.now());
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.primaryContainer.withValues(alpha: .45),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(strings.today),
            subtitle: Text(_date(today)),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.date_range_outlined),
            title: Text(strings.selected),
            subtitle: Text(
              strings.dates(_date(week.monday), _date(week.dateAt(5))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(
    AgendaWeek week,
    AgendaDay day,
    int index,
    AgendaStrings strings,
  ) => Card.outlined(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.day(index)),
            subtitle: Text(
              '${_date(week.dateAt(index))} · ${day.open ? strings.open : strings.closed}',
            ),
            value: day.open,
            onChanged: _model.busy
                ? null
                : (open) => _model.setOpen(index, open),
          ),
          if (day.open) ...[
            for (final (spanIndex, span) in day.spans.indexed) ...[
              const Divider(),
              Text(
                strings.span(spanIndex + 1),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Row(
                children: [
                  Expanded(
                    child: _timeButton(
                      index,
                      spanIndex,
                      strings.start,
                      span.start,
                      start: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _timeButton(
                      index,
                      spanIndex,
                      strings.end,
                      span.end,
                      start: false,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _model.busy
                      ? null
                      : () => _model.removeSpan(index, spanIndex),
                  child: Text(strings.remove(spanIndex + 1)),
                ),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _model.busy ? null : () => _model.addSpan(index),
              icon: const Icon(Icons.add),
              label: Text(strings.add),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _timeButton(
    int index,
    int span,
    String label,
    String value, {
    required bool start,
  }) => OutlinedButton(
    onPressed: _model.busy
        ? null
        : () => _pick(index, span, start: start, value: value),
    child: Text('$label · ${value.isEmpty ? '--:--' : value}'),
  );
}
