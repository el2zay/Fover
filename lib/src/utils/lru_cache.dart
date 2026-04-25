// libAI Generaed

class LruCache<K, V> {
  final int capacity;
  final _cache = <K, V>{};

  LruCache(this.capacity);

  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    final value = _cache.remove(key) ?? (throw StateError('Key not found'));
    _cache[key] = value;
    return value;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  void remove(K key) => _cache.remove(key);

  void clear() => _cache.clear();
}