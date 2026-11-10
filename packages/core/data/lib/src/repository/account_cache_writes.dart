/// Prevents a subscription from rewriting a cleared account's local data.
class AccountCacheWrites {
  final _generations = <String, int>{};
  final _pending = <String, Set<Future<void>>>{};

  int generation(String uid) => _generations[uid] ?? 0;

  Future<void> write(
    String uid,
    int generation,
    Future<void> Function() action,
  ) async {
    if (this.generation(uid) != generation) return;
    final writes = _pending.putIfAbsent(uid, () => {});
    final pending = action();
    writes.add(pending);
    try {
      await pending;
    } finally {
      writes.remove(pending);
      if (writes.isEmpty) _pending.remove(uid);
    }
  }

  Future<void> invalidate(String uid) async {
    _generations[uid] = generation(uid) + 1;
    await Future.wait([
      for (final write in _pending[uid] ?? const <Future<void>>{})
        write.catchError((Object _) {}),
    ]);
  }
}
