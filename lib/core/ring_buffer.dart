/// Fixed-capacity ring buffer (PLAN.md §5.3) — the last N items with O(1) add,
/// no per-frame allocation once warmed up. Used to hold the last ~64 frames
/// (~2.5s) for engines that need a sliding window without unbounded growth.
class RingBuffer<T> {
  RingBuffer(this.capacity) : _items = List<T?>.filled(capacity, null);

  final int capacity;
  final List<T?> _items;
  int _writeIndex = 0;
  int _length = 0;

  int get length => _length;
  bool get isFull => _length == capacity;

  void add(T item) {
    _items[_writeIndex] = item;
    _writeIndex = (_writeIndex + 1) % capacity;
    if (_length < capacity) _length++;
  }

  /// Most recently added item, or null if empty.
  T? get last =>
      _length == 0 ? null : _items[(_writeIndex - 1 + capacity) % capacity];

  /// Items oldest-to-newest.
  List<T> toList() {
    final start = isFull ? _writeIndex : 0;
    return [
      for (var i = 0; i < _length; i++) _items[(start + i) % capacity] as T,
    ];
  }

  void clear() {
    _length = 0;
    _writeIndex = 0;
  }
}
