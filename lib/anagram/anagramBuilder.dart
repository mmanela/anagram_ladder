import 'dart:convert';
import 'dart:io';

import 'package:anagram_ladder/datastructures/multiTrie.dart';

import 'fileUtils.dart';
import 'ladderLevel.dart';

class AnagramLadderBuilder {
  static const int RandomSeedNumber = 888;
  static const int LaddersPerSeedLength = 250;
  static const int MinimumRungCount = 3;
  static const int LevelsToRandomize = 1;
  static const int MinimumWordLength = 4;
  static const Map<int, int> MinimumWordLengthMap = {
    6: 4,
    7: 4,
    8: 5,
    9: 5,
    10: 5,
  };
  static const int SeedWordLengthMax = 10;
  static const int SeedWordLengthMin = 6;

  static const List<String> scowlEasyFileNames = [
    'american-words.10',
    'english-words.10',
    'american-words.20',
    'english-words.20',
    'american-words.35',
    'english-words.35',
  ];
  static const List<String> scowlMediumFileNames = [];
  static const List<String> scowlHardFileNames = [
    'american-words.40',
    'english-words.40',
    'american-words.50',
    'english-words.50',
    'american-words.55',
    'english-words.55',
    'american-words.60',
    'english-words.60',
    'american-words.70',
    'english-words.70',
  ];
  static String getGameLadderSetPath(int length) =>
      'tools/langs/en/processed/ladders_$length.json';
  static String getScowlFile(String name) => 'tools/langs/en/raw/Scowl/$name';
  static const String NounListPath =
      'tools/langs/en/raw/GreatNounList/noun_list.txt';
  static const String BlackListFilePath = 'tools/langs/en/raw/blacklist.txt';
  static const String ExtraWordFilePath = 'tools/langs/en/raw/extra_words.txt';
  static const String ProcessWordFilePath =
      'tools/langs/en/processed/words.txt';
  static const String RequiredWordFilePath =
      'tools/langs/en/processed/requiredWords.txt';
  static const String SeedLetterSetPath =
      'tools/langs/en/processed/seedLetterSets.txt';

  final String wordsPath;
  final String requiredWordsPath;
  final String seedsPath;
  MuliTrie<String, String, String>? _allLetterTrie;
  MuliTrie<String, String, String>? _requiredLetterTrie;
  final Map<String, _LadderPaths?> _pathCache = {};

  AnagramLadderBuilder({
    this.wordsPath = ProcessWordFilePath,
    this.requiredWordsPath = RequiredWordFilePath,
    this.seedsPath = SeedLetterSetPath,
  });

  Future<void> _buildLetterTrie() async {
    final allWords = await linesFromFile(wordsPath);
    final requiredWords = await linesFromFile(requiredWordsPath);
    final validWord = RegExp(r'^[a-z]{4,10}$');
    if ([
      ...allWords,
      ...requiredWords,
    ].any((word) => !validWord.hasMatch(word))) {
      throw const FormatException(
        'Malformed vocabulary; run process_raw and review its exclusions',
      );
    }
    final allowed = allWords.toSet();
    final required = requiredWords.toSet();
    if (allowed.length != allWords.length ||
        required.length != requiredWords.length) {
      throw const FormatException('Duplicate vocabulary entries');
    }
    if (!allowed.containsAll(required)) {
      throw StateError('Required vocabulary must be a subset of allowed words');
    }
    _allLetterTrie = MuliTrie<String, String, String>.fromIterable(
      allowed,
      parts: (word) => word.split('')..sort(),
    );
    _requiredLetterTrie = MuliTrie<String, String, String>.fromIterable(
      required,
      parts: (word) => word.split('')..sort(),
    );
  }

  Future<LadderLevel?> buildLadder(
    String seed, {
    int randomSeed = RandomSeedNumber,
  }) async {
    if (!RegExp(r'^[a-z]{6,10}$').hasMatch(seed)) {
      throw ArgumentError.value(
        seed,
        'seed',
        'Expected 6 to 10 lowercase ASCII letters',
      );
    }
    if (_allLetterTrie == null) await _buildLetterTrie();
    final letters = (seed.split('')..sort()).join();
    return _choosePath(
      _getPaths(letters, MinimumWordLengthMap[seed.length]!),
      _LadderChoices(randomSeed),
    );
  }

  Future<Map<int, List<LadderLevel>>> buildLadders() async {
    final seeds = (await linesFromFile(seedsPath)).toSet().toList()..sort();
    final groups = {
      for (final length in MinimumWordLengthMap.keys) length: <LadderLevel>[],
    };
    for (var index = 0; index < seeds.length; index++) {
      final ladder = await buildLadder(
        seeds[index],
        randomSeed: RandomSeedNumber + index,
      );
      if (ladder != null &&
          ladder.letterCount == seeds[index].length &&
          ladder.rung + 1 >= MinimumRungCount) {
        groups[ladder.letterCount]!.add(ladder);
      }
    }
    for (final entry in groups.entries) {
      entry.value.sort();
      if (entry.value.length < LaddersPerSeedLength) {
        throw StateError(
          'Not enough ${entry.key}-letter ladders: ${entry.value.length}',
        );
      }
      groups[entry.key] = entry.value.take(LaddersPerSeedLength).toList();
    }
    return groups;
  }

  Future<Map<int, List<LadderLevel>>> repairShortLadders() async {
    final seeds = (await linesFromFile(seedsPath)).toSet().toList()..sort();
    final result = <int, List<LadderLevel>>{};
    for (final length in MinimumWordLengthMap.keys) {
      final raw = jsonDecode(
        await File(getGameLadderSetPath(length)).readAsString(),
      ) as List<dynamic>;
      final ladders = raw
          .map((value) => LadderLevel.fromJson(value as Map<String, dynamic>))
          .toList();
      final used = ladders.map((ladder) => ladder.letters.join()).toSet();
      final replacements = seeds
          .where((seed) => seed.length == length && !used.contains(seed))
          .iterator;
      for (var index = 0; index < ladders.length; index++) {
        if (ladders[index].rung + 1 >= MinimumRungCount) continue;
        if (index < 50) {
          throw StateError(
            'Cannot repair immutable level $length/${index + 1}',
          );
        }
        var ladder = await buildLadder(
          ladders[index].letters.join(),
          randomSeed: index,
        );
        while (ladder == null ||
            ladder.letterCount != length ||
            ladder.rung + 1 < MinimumRungCount) {
          if (!replacements.moveNext()) {
            throw StateError('Not enough replacement ladders for $length');
          }
          ladder = await buildLadder(replacements.current, randomSeed: index);
        }
        ladders[index] = ladder;
        used.add(ladder.letters.join());
      }
      result[length] = ladders;
    }
    return result;
  }

  _LadderPaths? _getPaths(String letters, int minimum) {
    final key = '$minimum:$letters';
    if (_pathCache.containsKey(key)) return _pathCache[key];
    final words = (_requiredLetterTrie![letters]?.isNotEmpty ?? false)
        ? (_allLetterTrie![letters]!.toList()..sort())
        : <String>[];
    final children = <_LadderPaths>[];
    if (letters.length > minimum) {
      for (var index = 0; index < letters.length; index++) {
        if (index > 0 && letters[index] == letters[index - 1]) continue;
        final child = _getPaths(
          letters.substring(0, index) + letters.substring(index + 1),
          minimum,
        );
        if (child != null) children.add(child);
      }
    }
    if (words.isEmpty && children.isEmpty) return _pathCache[key] = null;
    if (children.isNotEmpty) {
      final longest = children
          .map((child) => child.rungCount)
          .reduce((a, b) => a > b ? a : b);
      children.removeWhere((child) => child.rungCount != longest);
      if (letters.length > minimum + LevelsToRandomize) {
        final counts = children.map((child) => child.wordCount).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
        final preferred = counts.take(2).toSet();
        children.removeWhere((child) => !preferred.contains(child.wordCount));
      }
      children.sort((a, b) => a.letters.compareTo(b.letters));
    }
    return _pathCache[key] = _LadderPaths(letters, words, children);
  }

  LadderLevel? _choosePath(_LadderPaths? paths, _LadderChoices choices) {
    if (paths == null) return null;
    final child = paths.children.isEmpty
        ? null
        : _choosePath(
            paths.children[choices.next(paths.children.length)],
            choices,
          );
    if (paths.words.isEmpty) return child;
    final letters = paths.letters.split('');
    final words = List<String>.of(paths.words);
    return child == null
        ? LadderLevel.bottom(letters, words.length, words)
        : LadderLevel(letters, words.length, child, words);
  }
}

class _LadderPaths {
  final String letters;
  final List<String> words;
  final List<_LadderPaths> children;
  final int rungCount;
  final int wordCount;

  _LadderPaths(this.letters, this.words, this.children)
    : rungCount =
          (words.isEmpty ? 0 : 1) +
          (children.isEmpty ? 0 : children.first.rungCount),
      wordCount = words.isNotEmpty
          ? words.length
          : children
                .map((child) => child.wordCount)
                .fold(0, (a, b) => a > b ? a : b);
}

// An explicit PRNG keeps candidate selection stable across Dart platforms.
class _LadderChoices {
  int _state;
  _LadderChoices(int seed) : _state = seed % 2147483646 + 1;

  int next(int count) {
    _state = _state * 48271 % 2147483647;
    return _state % count;
  }
}
