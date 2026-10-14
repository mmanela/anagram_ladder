import 'package:anagram_ladder/datastructures/multiTrie.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anagrams share a key and expose standard MapEntry values', () {
    final trie = MuliTrie<String, String, String>.fromIterable([
      'tea',
      'eat',
      'team',
    ], parts: (word) => word.split('')..sort());

    expect(trie.length, 2);
    expect(trie['ate'], {'tea', 'eat'});
    expect(trie.entries, everyElement(isA<MapEntry<String, Set<String>>>()));
    expect(
      trie.entries.map((entry) => entry.value),
      contains(unorderedEquals(['tea', 'eat'])),
    );
    expect(trie.keysWithPrefix('ae'), unorderedEquals(['eat', 'team']));
    expect(trie.entriesWithPrefix('ae').length, 2);

    trie.remove('ate');
    expect(trie.containsKey('tea'), isFalse);
    expect(trie['mate'], {'team'});
    expect(trie.length, 1);

    trie.clear();
    expect(trie.entries, isEmpty);
    expect(trie.length, 0);
  });
}
