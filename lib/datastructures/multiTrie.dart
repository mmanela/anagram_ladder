import 'dart:collection';

/// Function to extract the parts of type [P] from a key of type [K].
typedef GetParts<K, P> = Iterable<P> Function(K key);

/// A generalized [MuliTrie] (or prefix tree) which keys of type [K] split into
/// parts of type [P], and values of type [V].
class MuliTrie<K, P extends Comparable<P>, V> extends MapBase<K, Set<V>> {
  /// Creates an empty [MuliTrie] that splits the keys of type [K] into [parts] of
  /// type [P] with the provided function. Optionally a custom [root] node can
  /// be provided.
  factory MuliTrie({required GetParts<K, P> parts, TrieNode<K, P, V>? root}) =>
      MuliTrie._(root ?? TrieNodeList<K, P, V>(), parts);

  /// Creates a [MuliTrie] from another instance. Optionally redefines how the
  /// [parts] of the keys are computed and provides a custom [root] node.
  factory MuliTrie.fromTrie(MuliTrie<K, P, V> other,
          {GetParts<K, P>? parts, TrieNode<K, P, V>? root}) =>
      MuliTrie<K, P, V>.fromMap(other,
          parts: parts ?? other._getParts, root: root);

  /// Creates a [MuliTrie] from a [Map]. The [parts] define how the keys are
  /// computed and optionally provides a custom [root] node.
  factory MuliTrie.fromMap(Map<K, Set<V>> other,
      {required GetParts<K, P> parts, TrieNode<K, P, V>? root}) {
    final result = MuliTrie<K, P, V>(parts: parts, root: root);
    result.addAll(other);
    return result;
  }

  /// Creates a [MuliTrie] from an iterable (and possible transformation functions).
  /// The [parts] define how the keys are computed and optionally provides a
  /// custom [root] node.
  factory MuliTrie.fromIterable/*<E>*/(
    Iterable/*<E>*/ iterable, {
    required GetParts<K, P> parts,
    TrieNode<K, P, V>? root,
    // ignore: use_function_type_syntax_for_parameters
    K key(/*E*/ element)?,
    // ignore: use_function_type_syntax_for_parameters
    V value(/*E*/ element)?,
  }) =>
      MuliTrie<K, P, V>.fromIterables(
          key == null ? iterable.cast<K>() : iterable.map(key),
          value == null ? iterable.cast<V>() : iterable.map(value),
          parts: parts,
          root: root);

  /// Creates a [MuliTrie] from two equal length iterables. The [parts] define how
  /// the keys are computed and optionally provides a custom [root] node.
  factory MuliTrie.fromIterables(Iterable<K> keys, Iterable<V> values,
      {required GetParts<K, P> parts, TrieNode<K, P, V>? root}) {
    final result = MuliTrie<K, P, V>(parts: parts, root: root);
    final keyIterator = keys.iterator;
    final valueIterator = values.iterator;
    var moreKeys = keyIterator.moveNext();
    var moreValues = valueIterator.moveNext();
    while (moreKeys && moreValues) {
      result.add(keyIterator.current, valueIterator.current);
      moreKeys = keyIterator.moveNext();
      moreValues = valueIterator.moveNext();
    }
    if (moreKeys || moreValues) {
      throw ArgumentError('Keys and values iterables have different length.');
    }
    return result;
  }

  /// Function to extract the parts from the key.
  final GetParts<K, P> _getParts;

  /// Root node of the tree.
  final TrieNode<K, P, V> _root;

  /// Number of key-value pairs in the tree.
  int _length = 0;

  /// Internal constructor of the [MuliTrie].
  MuliTrie._(this._root, this._getParts)
      : assert(!_root.hasKeyAndValue,
            'The initial root should not have a key or value.'),
        assert(!_root.hasChildren,
            'The initial root node should not have children.');

  @override
  int get length => _length;

  @override
  Set<V>? operator [](Object? key) {
    if (key is K) {
      var current = _root;
      // Navigate to the right node.
      for (final part in _getParts(key)) {
        final node = current.getChild(part);
        if (node == null) {
          return null;
        }
        current = node;
      }
      // Verify we found a value node.
      if (current.hasKeyAndValue) {
        return current.value;
      }
    }
    return null;
  }

  @override
  bool containsKey(Object? key) {
    if (key is K) {
      var current = _root;
      // Navigate to the right node.
      for (final part in _getParts(key)) {
        final node = current.getChild(part);
        if (node == null) {
          return false;
        }
        current = node;
      }
      // Verify we found a value node.
      return current.hasKeyAndValue;
    }
    return false;
  }

  void add(K key, V value) {
    var current = _root;
    // Navigate to the right node, create intermediaries as necessary.
    for (final part in _getParts(key)) {
      current = current.addChild(part);
    }
    // Increment the length only if no value existed before.
    if (!current.hasKeyAndValue) {
      _length++;
    }
    // Update key and value of the node.
    current.setKeyAndValue(key, value);
  }

  @override
  void operator []=(K key, Set<V> value) {
    var current = _root;
    // Navigate to the right node, create intermediaries as necessary.
    for (final part in _getParts(key)) {
      current = current.addChild(part);
    }
    // Increment the length only if no value existed before.
    if (!current.hasKeyAndValue) {
      _length++;
    }
    // Update key and value of the node.
    current.setKeyAndValueSet(key, value);
  }

  @override
  void clear() {
    _root.clearChildren();
    _root.clearKeyAndValue();
    _length = 0;
  }

  @override
  Set<V>? remove(Object? key) {
    if (key is K) {
      final parts = <P>[];
      final nodes = <TrieNode<K, P, V>>[_root];
      // Navigate to the right node.
      for (final part in _getParts(key)) {
        final node = nodes.last.getChild(part);
        if (node == null) {
          return null;
        }
        parts.add(part);
        nodes.add(node);
      }
      // Verify we found a value node.
      var current = nodes.removeLast();
      if (current.hasKeyAndValue) {
        // Remove the value from the tree.
        final value = current.value;
        current.clearKeyAndValue();
        _length--;
        // Cleanup no longer needed subtrees.
        while (nodes.isNotEmpty &&
            parts.isNotEmpty &&
            !current.hasKeyAndValue &&
            !current.hasChildren) {
          current = nodes.removeLast();
          current.removeChild(parts.removeLast());
        }
        // Return the value of the remove node.
        return value;
      }
    }
    return null;
  }

  @override
  Iterable<MapEntry<K, Set<V>>> get entries => _root.entries;

  @override
  Iterable<K> get keys => entries.map((entry) => entry.key);

  @override
  Iterable<Set<V>> get values => entries.map((entry) => entry.value);

  /// An [Iterable] over the [MapEntry] objects with [prefix].
  Iterable<MapEntry<K, Set<V>>> entriesWithPrefix(K prefix) {
    var current = _root;
    for (final part in _getParts(prefix)) {
      final node = current.getChild(part);
      if (node == null) {
        return const [];
      }
      current = node;
    }
    return current.entries;
  }

  /// An [Iterable] over all keys starting with [prefix].
  Iterable<K> keysWithPrefix(K prefix) =>
      entriesWithPrefix(prefix).map((entry) => entry.key);
}

/// Abstract implementation of the nodes in a [MuliTrie].
abstract class TrieNode<K, P extends Comparable<P>, V>
    implements MapEntry<K, Set<V>> {
  /// Parts of the child nodes.
  Iterable<P> get parts;

  /// Ordered child nodes.
  Iterable<TrieNode<K, P, V>> get children;

  /// Returns `true`, if the node has child nodes.
  bool get hasChildren;

  /// Adds a new node with the provided [part], or returns the existing one.
  TrieNode<K, P, V> addChild(P part);

  /// Returns the node with the provided [part], or `null`.
  TrieNode<K, P, V>? getChild(P part);

  /// Returns the removed node with the provided [part], or `null`.
  TrieNode<K, P, V>? removeChild(P part);

  /// Clears all the child nodes.
  void clearChildren();

  /// Returns the key of the node, if this node has a key and value.
  @override
  K get key;

  /// Returns the value of the node, if this node has a key and value.
  @override
  Set<V> get value;

  /// Returns `true`, if the node has a key and value.
  bool get hasKeyAndValue;

  /// Clears the key and value, if present.
  void clearKeyAndValue();

  /// Sets (or replaces) the key and value.
  void setKeyAndValue(K key, V value);

  void setKeyAndValueSet(K key, Set<V> value);

  /// An iterable over this node and all its  children
  Iterable<MapEntry<K, Set<V>>> get entries sync* {
    final queue = [this];
    while (queue.isNotEmpty) {
      final element = queue.removeLast();
      if (element.hasKeyAndValue) {
        yield element;
      }
      final children = element.children
          .where((element) => element.hasKeyAndValue || element.hasChildren);
      queue.addAll(children.toList().reversed);
    }
  }
}

/// Abstract [TrieNode] with a possible key and value.
abstract class TrieNodeEntry<K, P extends Comparable<P>, V>
    extends TrieNode<K, P, V> {
  K? _key;

  Set<V> _value = Set();

  @override
  K get key => hasKeyAndValue ? _key! : throw UnimplementedError();

  @override
  Set<V> get value => hasKeyAndValue ? _value : throw UnimplementedError();

  @override
  bool hasKeyAndValue = false;

  @override
  void clearKeyAndValue() {
    _key = null;
    _value.clear();
    hasKeyAndValue = false;
  }

  @override
  void setKeyAndValue(K key, V value) {
    _key = key;
    _value.add(value);
    hasKeyAndValue = true;
  }

  @override
  void setKeyAndValueSet(K key, Set<V> value) {
    _key = key;
    _value = value;
    hasKeyAndValue = true;
  }
}

/// [TrieNode] that holds children in a [Map].
class TrieNodeMap<K, P extends Comparable<P>, V>
    extends TrieNodeEntry<K, P, V> {
  final Map<P, TrieNode<K, P, V>> _children = SplayTreeMap();

  @override
  Iterable<P> get parts => _children.keys;

  @override
  Iterable<TrieNode<K, P, V>> get children => _children.values;

  @override
  bool get hasChildren => _children.isNotEmpty;

  @override
  TrieNode<K, P, V> addChild(P part) =>
      _children.putIfAbsent(part, () => TrieNodeMap<K, P, V>());

  @override
  TrieNode<K, P, V>? getChild(P part) => _children[part];

  @override
  TrieNode<K, P, V>? removeChild(P part) => _children.remove(part);

  @override
  void clearChildren() => _children.clear();
}

/// [TrieNode] that holds children in a sorted [List].
class TrieNodeList<K, P extends Comparable<P>, V>
    extends TrieNodeEntry<K, P, V> {
  @override
  final List<P> parts = [];

  @override
  final List<TrieNode<K, P, V>> children = [];

  @override
  bool get hasChildren => children.isNotEmpty;

  @override
  TrieNode<K, P, V> addChild(P part) {
    final index = _binarySearch(part);
    if (index < 0) {
      final node = TrieNodeList<K, P, V>();
      parts.insert(-index - 1, part);
      children.insert(-index - 1, node);
      return node;
    } else {
      return children[index];
    }
  }

  @override
  TrieNode<K, P, V>? getChild(P part) {
    final index = _binarySearch(part);
    return index < 0 ? null : children[index];
  }

  @override
  TrieNode<K, P, V>? removeChild(P part) {
    final index = _binarySearch(part);
    if (index < 0) {
      return null;
    }
    final node = children[index];
    parts.removeAt(index);
    children.removeAt(index);
    return node;
  }

  @override
  void clearChildren() {
    parts.clear();
    children.clear();
  }

  int _binarySearch(P key) {
    var min = 0;
    var max = parts.length;
    while (min < max) {
      final mid = min + ((max - min) >> 1);
      final comp = parts[mid].compareTo(key);
      if (comp == 0) {
        return mid;
      } else if (comp < 0) {
        min = mid + 1;
      } else {
        max = mid;
      }
    }
    return -min - 1;
  }
}
