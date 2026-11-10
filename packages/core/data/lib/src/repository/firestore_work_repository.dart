import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:network/network.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_cache_writes.dart';
import 'cloudinary_booking_photo_repository.dart';
import 'local_work_draft_store.dart';
import 'work_image_cache.dart';

class FirestoreWorkRepository implements WorkRepository {
  FirestoreWorkRepository(
    this._firestore,
    this._auth,
    this._photos,
    this._storage,
  );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final CloudinaryBookingPhotoRepository _photos;
  final SharedPreferences _storage;
  final _images = const WorkImageCache();
  final _cacheWrites = AccountCacheWrites();
  final _drafts = LocalWorkDraftStore();
  final _uploads = <String, Future<CloudinaryPhoto>>{};
  final _downloads = <String, Future<Uint8List?>>{};
  final _prefetching = <String, Future<void>>{};
  static const _server = GetOptions(source: Source.server);

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('publicaciones');
  String get _uid => _auth.currentUser?.uid ?? (throw StateError('Sign in'));
  String _cacheKey(String uid) => 'work.feed.$uid';

  Future<void> clearLocal(String uid) async {
    final invalidate = _cacheWrites.invalidate(uid);
    _prefetching.remove(uid);
    _uploads.removeWhere((key, _) => key.startsWith('$uid/'));
    await invalidate;
    await Future.wait([
      _storage.remove(_cacheKey(uid)),
      _images.clear(_fileComponent(uid)),
      _drafts.clear(uid),
    ]);
  }

  bool _isCurrent(String uid, int generation) =>
      _auth.currentUser?.uid == uid &&
      _cacheWrites.generation(uid) == generation;

  @override
  Stream<WorkFeed> watch() async* {
    final uid = _uid;
    final key = _cacheKey(uid);
    final generation = _cacheWrites.generation(uid);
    List<WorkPost>? saved;
    final cached = _storage.getString(key);
    if (cached != null) {
      try {
        saved = [
          for (final row in jsonDecode(cached) as List)
            _decode(row['id'] as String, row as Map<String, dynamic>, uid),
        ];
      } on Exception {
        await _cacheWrites.write(uid, generation, () async {
          await _storage.remove(key);
        });
      } on TypeError {
        await _cacheWrites.write(uid, generation, () async {
          await _storage.remove(key);
        });
      }
    }
    if (!_isCurrent(uid, generation)) return;
    if (saved != null) yield WorkFeed(saved, offline: true);
    await for (final snapshot
        in _posts
            .orderBy('CreadoEn', descending: true)
            .limit(50)
            .snapshots(includeMetadataChanges: true)) {
      if (!_isCurrent(uid, generation)) return;
      if (snapshot.metadata.hasPendingWrites) continue;
      if (snapshot.metadata.isFromCache) {
        yield WorkFeed(saved ?? const [], offline: true);
        continue;
      }
      final rows = [
        for (final doc in snapshot.docs)
          {
            'id': doc.id,
            for (final key in [
              'BarberoId',
              'BarberoNombre',
              'ImagenUrl',
              'Descripcion',
            ])
              key: doc.data()[key],
          },
      ];
      saved = [for (final row in rows) _decode(row['id'] as String, row, uid)];
      final encoded = jsonEncode(rows);
      if (_storage.getString(key) != encoded) {
        try {
          await _cacheWrites.write(uid, generation, () async {
            await _storage.setString(key, encoded);
          });
        } on Exception {
          // Remote results remain usable if local storage is unavailable.
        }
      }
      if (!_isCurrent(uid, generation)) return;
      _queuePrefetch(uid, generation, saved);
      yield WorkFeed(saved, offline: false);
    }
  }

  WorkPost _decode(String id, Map<String, dynamic> data, String uid) {
    String text(String key) => data[key] is String ? data[key] as String : '';
    final barberId = text('BarberoId');
    return WorkPost(
      id: id,
      barberId: barberId,
      barberName: text('BarberoNombre'),
      imageUrl: text('ImagenUrl'),
      description: text('Descripcion'),
      isOwn: barberId == uid,
    );
  }

  void _queuePrefetch(String uid, int generation, List<WorkPost> posts) {
    final previous = _prefetching[uid] ?? Future.value();
    late final Future<void> next;
    next = previous
        .then((_) async {
          if (_prefetching[uid] != next || !_isCurrent(uid, generation)) {
            return;
          }
          try {
            await _cacheWrites.write(
              uid,
              generation,
              () => _images.retain(_fileComponent(uid), {
                for (final post in posts) _imageName(post),
              }),
            );
            for (var i = 0; i < posts.length; i += 3) {
              if (_prefetching[uid] != next || !_isCurrent(uid, generation)) {
                return;
              }
              await Future.wait(
                posts
                    .skip(i)
                    .take(3)
                    .map(
                      (post) => _image(uid, generation, post, offline: false),
                    ),
              );
            }
          } catch (_) {
            // An unavailable image can be retried by opening the feed again.
          }
        })
        .whenComplete(() {
          if (_prefetching[uid] == next) _prefetching.remove(uid);
        });
    _prefetching[uid] = next;
    unawaited(next);
  }

  String _fileComponent(String value) => base64Url.encode(utf8.encode(value));
  String _imageName(WorkPost post) => '${_fileComponent(post.id)}.jpg';

  @override
  Future<Uint8List?> readImage(WorkPost post, {required bool offline}) async {
    final uid = _uid;
    final generation = _cacheWrites.generation(uid);
    final bytes = await _image(uid, generation, post, offline: offline);
    return _isCurrent(uid, generation) ? bytes : null;
  }

  Future<Uint8List?> _image(
    String uid,
    int generation,
    WorkPost post, {
    required bool offline,
  }) async {
    final account = _fileComponent(uid);
    final name = _imageName(post);
    try {
      final cached = await _images.read(account, name);
      if (cached != null) return cached;
    } catch (_) {
      // Online photos remain available if the device blocks persistent storage.
    }
    if (offline || !_isCurrent(uid, generation)) return null;

    final key = '$account/$generation/$name';
    return _downloads.putIfAbsent(key, () async {
      try {
        final bytes = await _download(post.imageUrl);
        if (bytes != null && _isCurrent(uid, generation)) {
          try {
            await _cacheWrites.write(
              uid,
              generation,
              () => _images.write(account, name, bytes),
            );
          } catch (_) {
            // Keep displaying the downloaded photo even if it cannot be saved.
          }
        }
        return bytes;
      } finally {
        _downloads.remove(key);
      }
    });
  }

  Future<Uint8List?> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'res.cloudinary.com') {
      return null;
    }
    try {
      return await const NetworkClient().download(
        uri,
        maxBytes: 5 * 1024 * 1024,
        timeout: const Duration(seconds: 20),
      );
    } on Exception {
      return null;
    }
  }

  @override
  String newPostId() => _posts.doc().id;

  @override
  WorkDraftRepository openDrafts() {
    final uid = _uid;
    final generation = _cacheWrites.generation(uid);
    return SessionWorkDraftRepository(
      _drafts,
      uid,
      () => _isCurrent(uid, generation),
    );
  }

  @override
  Future<void> publish(
    String id,
    Uint8List image,
    String description, {
    required WorkFraming framing,
  }) async {
    final uid = _uid;
    final barber = _firestore.collection('barberos').doc(uid);
    final ref = _posts.doc(id);
    if ((await barber.get(_server)).data()?['Estado'] != true || _uid != uid) {
      throw StateError('Only active barbers can publish');
    }
    final existing = await ref.get(_server);
    final prefix = '$uid/$id/';
    final key = '$prefix${framing.horizontal}/${framing.vertical}';
    if (existing.exists) {
      if (existing.data()?['BarberoId'] != uid) {
        throw StateError('Invalid owner');
      }
      _uploads.removeWhere((key, _) => key.startsWith(prefix));
      return;
    }
    if (!_uploads.containsKey(key) && _uploads.length >= 20) {
      _uploads.remove(_uploads.keys.first);
    }
    final upload = _uploads.putIfAbsent(
      key,
      () => _photos.uploadPhoto(image, framing: framing),
    );
    final CloudinaryPhoto photo;
    try {
      photo = await upload;
    } catch (_) {
      if (_uploads[key] == upload) _uploads.remove(key);
      rethrow;
    }
    await _firestore.runTransaction((transaction) async {
      final previous = await transaction.get(ref);
      final profile = (await transaction.get(barber)).data();
      if (_uid != uid || profile?['Estado'] != true) {
        throw StateError('Barber is unavailable');
      }
      if (previous.exists) {
        if (previous.data()?['BarberoId'] != uid) {
          throw StateError('Invalid owner');
        }
        return;
      }
      transaction.set(ref, {
        'BarberoId': uid,
        'BarberoNombre': profile!['Nombre'],
        'ImagenUrl': photo.url,
        'ImagenPublicId': photo.publicId,
        'Descripcion': description,
        'CreadoEn': FieldValue.serverTimestamp(),
      });
    });
    _uploads.removeWhere((key, _) => key.startsWith(prefix));
  }

  Future<void> _change(String id, {String? description}) async {
    final uid = _uid;
    final ref = _posts.doc(id);
    await _firestore.runTransaction((transaction) async {
      final post = await transaction.get(ref);
      if (_uid != uid) throw StateError('Session changed');
      if (!post.exists && description == null) return;
      if (post.data()?['BarberoId'] != uid) throw StateError('Invalid owner');
      if (description == null) {
        transaction.delete(ref);
      } else {
        transaction.update(ref, {'Descripcion': description});
      }
    });
  }

  @override
  Future<void> edit(String id, String description) =>
      _change(id, description: description);

  @override
  Future<void> delete(String id) => _change(id);
}
