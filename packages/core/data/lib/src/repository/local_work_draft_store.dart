import 'dart:convert';
import 'dart:typed_data';

import 'package:domain/domain.dart';

import 'work_image_cache.dart';

class SessionWorkDraftRepository implements WorkDraftRepository {
  const SessionWorkDraftRepository(this._store, this._uid, this._isCurrent);

  final LocalWorkDraftStore _store;
  final String _uid;
  final bool Function() _isCurrent;

  @override
  Future<WorkDraft?> read() async {
    if (!_isCurrent()) return null;
    final draft = await _store.read(_uid);
    return _isCurrent() ? draft : null;
  }

  @override
  Future<void> save(WorkDraft draft) async {
    if (_isCurrent()) await _store.write(_uid, draft);
  }

  @override
  Future<void> discard() async {
    if (_isCurrent()) await _store.clear(_uid);
  }
}

/// Keeps each draft and its photo together, separate from the offline feed.
class LocalWorkDraftStore {
  static const _file = 'draft';
  final _cache = const WorkImageCache();
  Future<void> _pending = Future.value();

  String _account(String uid) => 'draft.${base64Url.encode(utf8.encode(uid))}';

  Future<WorkDraft?> read(String uid) async {
    await _pending;
    final bytes = await _cache.read(_account(uid), _file);
    if (bytes == null) return null;

    final separator = bytes.indexOf(10);
    if (separator < 0) return null;
    try {
      final header = jsonDecode(
        utf8.decode(Uint8List.sublistView(bytes, 0, separator)),
      );
      if (header
          case {
            'id': final String id,
            'description': final String description,
            'x': final num x,
            'y': final num y,
          }
          when RegExp(r'^[a-zA-Z0-9]{20}$').hasMatch(id) &&
              x >= -1 &&
              x <= 1 &&
              y >= -1 &&
              y <= 1) {
        return WorkDraft(
          id: id,
          description: description,
          framing: WorkFraming(
            horizontal: x.toDouble(),
            vertical: y.toDouble(),
          ),
          photo: separator + 1 < bytes.length
              ? Uint8List.sublistView(bytes, separator + 1)
              : null,
        );
      }
    } on FormatException {
      // An incomplete or invalid draft can be replaced by a fresh one.
    }
    return null;
  }

  Future<void> write(String uid, WorkDraft draft) => _enqueue(() async {
    final bytes = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          jsonEncode({
            'id': draft.id,
            'description': draft.description,
            'x': draft.framing.horizontal,
            'y': draft.framing.vertical,
          }),
        ),
      )
      ..addByte(10);
    if (draft.photo case final photo?) bytes.add(photo);
    await _cache.write(_account(uid), _file, bytes.takeBytes());
  });

  Future<void> clear(String uid) => _enqueue(() => _cache.clear(_account(uid)));

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
