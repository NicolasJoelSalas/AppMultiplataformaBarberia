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

abstract interface class WorkRepository {
  Stream<WorkFeed> watch();
  Future<Uint8List?> readImage(WorkPost post, {required bool offline});
  String newPostId();
  Future<void> publish(String id, Uint8List image, String description);
  Future<void> edit(String id, String description);
  Future<void> delete(String id);
}

class SaveWorkPost {
  const SaveWorkPost(this.repository);

  static const maxDescription = 300;
  final WorkRepository repository;

  Future<void> call(String id, String description, {Uint8List? image}) {
    final normalized = description.trim();
    if (normalized.length > maxDescription || image?.isEmpty == true) {
      throw ArgumentError('Invalid post');
    }
    return image == null
        ? repository.edit(id, normalized)
        : repository.publish(id, image, normalized);
  }
}
