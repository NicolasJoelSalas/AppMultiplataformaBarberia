import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

class WorkViewModel extends ChangeNotifier {
  WorkViewModel(this._repository) : _save = SaveWorkPost(_repository);

  final WorkRepository _repository;
  final SaveWorkPost _save;
  late final _drafts = _repository.openDrafts();
  StreamSubscription<WorkFeed>? _subscription;
  WorkFeed? feed;
  bool failed = false;
  bool get offline => feed?.offline == true || failed;

  void start() {
    unawaited(_subscription?.cancel());
    failed = false;
    _subscription = _repository.watch().listen(
      (value) {
        feed = value;
        failed = false;
        notifyListeners();
      },
      onError: (Object _) {
        failed = true;
        notifyListeners();
      },
    );
    notifyListeners();
  }

  String newPostId() => _repository.newPostId();

  Future<Uint8List?> readImage(WorkPost post) =>
      _repository.readImage(post, offline: offline);

  Future<WorkDraft?> readDraft() => _drafts.read();

  Future<void> saveDraft(WorkDraft draft) => _drafts.save(draft);

  Future<void> discardDraft() => _drafts.discard();

  Future<void> editDescription(WorkPost post, String description) =>
      _save(post.id, description);

  Future<void> publish(WorkDraft draft) async {
    final photo = draft.photo;
    if (photo == null) throw StateError('Missing photo');
    await _save(
      draft.id,
      draft.description,
      image: photo,
      framing: draft.framing,
    );
  }

  Future<void> delete(WorkPost post) => _repository.delete(post.id);

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
