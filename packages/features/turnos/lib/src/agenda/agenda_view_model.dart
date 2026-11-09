import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

class AgendaViewModel extends ChangeNotifier {
  AgendaViewModel(this._repository)
    : _publish = SaveAndPublishAgenda(_repository);

  final AgendaRepository _repository;
  final SaveAndPublishAgenda _publish;
  final _drafts = <int, _Draft>{};
  int _offset = 0;
  bool _loading = false;
  bool _saving = false;
  bool _disposed = false;
  AgendaProblem? _loadProblem;

  _Draft? get _selected => _drafts[_offset];
  AgendaWeek? get week => _selected?.current;
  AgendaPublication? get publication => _selected?.publication;
  AgendaProblem? get problem =>
      _loadProblem ?? _selected?.problem ?? publication?.problem;
  int get offset => _offset;
  bool get loading => _loading;
  bool get saving => _saving;
  bool get busy => _loading || _saving;
  bool get hasChanges => _drafts.values.any((draft) => draft.changed);
  bool get selectedHasChanges => _selected?.changed ?? false;

  void discardChanges() {
    _drafts.updateAll(
      (_, draft) => draft.changed ? _Draft(draft.original) : draft,
    );
    _notify();
  }

  Future<void> select(int offset) async {
    if (busy || offset == _offset || _disposed) return;
    _offset = offset;
    _loadProblem = null;
    if (_selected == null) {
      await load();
    } else {
      _notify();
    }
  }

  Future<void> load() async {
    if (busy || _disposed) return;
    _loading = true;
    _loadProblem = null;
    _notify();
    try {
      _drafts[_offset] = _Draft(await _repository.load(_offset));
    } on AgendaProblem catch (problem) {
      _loadProblem = problem;
    } catch (_) {
      _loadProblem = const AgendaProblem(AgendaFailure.operation);
    } finally {
      _loading = false;
      _notify();
    }
  }

  void setOpen(int index, bool open) => _edit(
    index,
    (day) => AgendaDay(
      open: open,
      spans: open && day.spans.isEmpty ? const [AgendaSpan('', '')] : day.spans,
    ),
  );

  void addSpan(int index) => _edit(
    index,
    (day) =>
        AgendaDay(open: true, spans: [...day.spans, const AgendaSpan('', '')]),
  );

  void removeSpan(int index, int span) => _edit(index, (day) {
    final spans = [...day.spans]..removeAt(span);
    return AgendaDay(open: spans.isNotEmpty && day.open, spans: spans);
  });

  void setTime(
    int index,
    int span, {
    required bool start,
    required String value,
  }) => _edit(index, (day) {
    final previous = day.spans[span];
    final next = start
        ? AgendaSpan(value, previous.end)
        : AgendaSpan(previous.start, value);
    return AgendaDay(open: day.open, spans: [...day.spans]..[span] = next);
  });

  void _edit(int index, AgendaDay Function(AgendaDay) edit) {
    final draft = _selected;
    if (draft == null || busy || _disposed) return;
    draft.current = draft.current.withDay(
      index,
      edit(draft.current.days[index]),
    );
    draft.problem = null;
    draft.publication = null;
    _loadProblem = null;
    _notify();
  }

  Future<void> save() async {
    final draft = _selected;
    if (draft == null || busy || _disposed) return;
    _saving = true;
    draft.problem = null;
    draft.publication = null;
    _loadProblem = null;
    _notify();
    try {
      draft.publication = await _publish(draft.current);
      draft.original = draft.current;
    } on AgendaProblem catch (problem) {
      draft.problem = problem;
    } catch (_) {
      draft.problem = const AgendaProblem(AgendaFailure.operation);
    } finally {
      _saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _Draft {
  _Draft(this.original) : current = original;

  AgendaWeek original;
  AgendaWeek current;
  AgendaProblem? problem;
  AgendaPublication? publication;

  bool get changed => !current.sameSchedule(original);
}
