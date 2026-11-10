import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

class WorkViewModel extends ChangeNotifier {
  WorkViewModel(this._repository) : _save = SaveWorkPost(_repository);

  final WorkRepository _repository;
  final SaveWorkPost _save;
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

  Future<void> save(String id, String description, {Uint8List? image}) =>
      _save(id, description, image: image);

  Future<void> delete(WorkPost post) => _repository.delete(post.id);

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
