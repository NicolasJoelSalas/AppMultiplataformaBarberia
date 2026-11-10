import 'dart:typed_data';

class WorkPost {
  const WorkPost({
    required this.id,
    required this.barberId,
    required this.barberName,
    required this.imageUrl,
    required this.description,
    required this.isOwn,
  });

  final String id;
  final String barberId;
  final String barberName;
  final String imageUrl;
  final String description;
  final bool isOwn;
}

class WorkFeed {
  const WorkFeed(this.posts, {required this.offline});
  final List<WorkPost> posts;
  final bool offline;
}

class WorkFraming {
  const WorkFraming({this.horizontal = 0, this.vertical = 0})
    : assert(horizontal >= -1 && horizontal <= 1),
      assert(vertical >= -1 && vertical <= 1);

  final double horizontal;
  final double vertical;
}

class WorkDraft {
  const WorkDraft({
    required this.id,
    this.description = '',
    this.photo,
    this.framing = const WorkFraming(),
  });

  final String id;
  final String description;
  final Uint8List? photo;
  final WorkFraming framing;
}

abstract interface class WorkDraftRepository {
  Future<WorkDraft?> read();
  Future<void> save(WorkDraft draft);
  Future<void> discard();
}

abstract interface class WorkRepository {
  Stream<WorkFeed> watch();
  Future<Uint8List?> readImage(WorkPost post, {required bool offline});
  String newPostId();
  WorkDraftRepository openDrafts();
  Future<void> publish(
    String id,
    Uint8List image,
    String description, {
    required WorkFraming framing,
  });
  Future<void> edit(String id, String description);
  Future<void> delete(String id);
}

class SaveWorkPost {
  const SaveWorkPost(this.repository);

  static const maxDescription = 300;
  final WorkRepository repository;

  Future<void> call(
    String id,
    String description, {
    Uint8List? image,
    WorkFraming framing = const WorkFraming(),
  }) {
    final normalized = description.trim();
    if (normalized.length > maxDescription || image?.isEmpty == true) {
      throw ArgumentError('Invalid post');
    }
    return image == null
        ? repository.edit(id, normalized)
        : repository.publish(id, image, normalized, framing: framing);
  }
}
