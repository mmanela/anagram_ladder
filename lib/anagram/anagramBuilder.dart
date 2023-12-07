import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:anagram_ladder/datastructures/multiTrie.dart';
import 'package:trotter/trotter.dart';
import 'package:more/collection.dart';
import 'fileUtils.dart';
import 'ladderLevel.dart';
import "package:collection/collection.dart";

enum LogLevel { None, Error, Warning, Info, Verbose }

class AnagramLadderBuilder {
  static const int RandomSeedNumber = 888;
  final LogLevel _logLevel = LogLevel.Info;
  static const int LaddersPerSeedLength = 250;
  static const int LevelsToRandomize = 1;
  static const int MinimumWordLength = 4;

  // Variable minimums so its not too repetitive on higher levels
  static const Map<int, int> MinimumWordLengthMap = {
    6: MinimumWordLength,
    7: MinimumWordLength,
    8: MinimumWordLength + 1,
    9: MinimumWordLength + 1,
    10: MinimumWordLength + 1
  };
  static const int SeedWordLengthMax = 10;
  static const int SeedWordLengthMin = 6;

  static List<String> scowlEasyFileNames = [
    'american-words.10',
    'english-words.10',
    'american-words.20',
    'english-words.20',
    'american-words.35',
    'english-words.35',
  ];
  static List<String> scowlMediumFileNames = [];
  static List<String> scowlHardFileNames = [
    'american-words.40',
    'english-words.40',
    'american-words.50',
    'english-words.50',
    'american-words.55',
    'english-words.55',
    'american-words.60',
    'english-words.60',
    'american-words.70',
    'english-words.70'
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

  final _random = Random(RandomSeedNumber);
  MuliTrie<String, String, String>? _allLetterTrie;
  MuliTrie<String, String, String>? _requiredLetterTrie;
  Map<String, List<LadderLevel?>> _ladderCache = {};

  Future<void> _buildLetterTrie() async {
    List<String> allWords = await linesFromFile(ProcessWordFilePath);
    List<String> requiredWords = await linesFromFile(RequiredWordFilePath);

    // Letter trie always sorts keys in alphabetically and stores
    // all words that can come from each one
    _allLetterTrie = MuliTrie<String, String, String>.fromIterable(allWords,
        parts: (String k) {
      final s = k.toList(mutable: true)..sort();
      return s;
    });
    _requiredLetterTrie = MuliTrie<String, String, String>.fromIterable(
        requiredWords, parts: (String k) {
      final s = k.toList(mutable: true)..sort();
      return s;
    });
  }

  Future<void> buildLadders() async {
    List<String> seeds = await linesFromFile(SeedLetterSetPath);

    // Build the trie first
    await _buildLetterTrie();

    _log("Start Building Levels", LogLevel.Info);
    final levels = seeds
        .indices()
        .map((i) => _buildLadder(seeds[i], i))
        .where((e) => e != null)
        .toList();

    _log("Stop Building Levels", LogLevel.Info);

    _log("Create Top $LaddersPerSeedLength for each max levels", LogLevel.Info);
    final groups = groupBy(levels, (LadderLevel? level) => level!.letterCount);
    _log("Built ${groups.length} groups of levels", LogLevel.Info);
    groups.entries.forEach((element) async {
      var levelLadders = element.value.toList();
      _log("Start Sorting Levels for length ${element.key}", LogLevel.Info);
      levelLadders.sort();
      _log("Stop Sorting Levels", LogLevel.Info);

      await writeLadderFile(element.key,
          levelLadders.cast<LadderLevel>().take(LaddersPerSeedLength).toList());

      printStartingWordHistogram(levelLadders, element.key);
    });

    // print("Non-4s");
    // levels
    //     .where((e) => _getBottom(e!).letterCount > 4)
    //     .take(10)
    //     .forEach((level) {
    //   print("\n=======\n$level\n");
    // });

    // MinimumWordLengthMap.keys.forEach((element) {
    //   printStartingWordHistogram(levels, element);
    // });

    // print("Sample of levels");
    // levels.take(1).forEach((level) {
    //   print("\n=======\n$level\n");
    // });
  }

  void printStartingWordHistogram(List<LadderLevel?> levels, int levelNum) {
    print("\nDistribution of start words in $levelNum letter words");
    final groupedLadders = levels.take(50).toList();
    final firstLevels = groupedLadders
        .map((e) => e!.getBottom())
        .map((e) => e.letters.join())
        .toList();
    final countMapFirstLevels =
        firstLevels.fold<Map<String, int>>(Map<String, int>(), (map, element) {
      map.update(element, (value) => value + 1, ifAbsent: () => 1);
      return map;
    });
    final pairList = countMapFirstLevels.entries.toList()
      ..sort((e1, e2) {
        return e1.value - e2.value;
      });
    pairList.forEach((element) {
      print("${element.value} - ${element.key}");
    });
  }

  // We need our own method since trotter doesn't like duplicate values
  // but we need them so we use indices to map to positions of letters
  Iterable<List<String>> _getCombinations(List<String> items) sync* {
    var indices = IntegerRange(items.length);
    final combos = Combinations(items.length - 1, indices)();
    for (final combo in combos) {
      final strList = combo.map((index) => items[index.floor()]).toList();
      yield strList;
    }
  }

  void _log(String message, LogLevel level) {
    if (level.index <= _logLevel.index) {
      print("!!! $message at ${_getNow()}");
    }
  }

  String _getNow() {
    return DateTime.now().toLocal().toIso8601String();
  }

  LadderLevel? _buildLadder(String seed, int index) {
    try {
      _log("Start building ladder for $seed", LogLevel.Verbose);
      final minWordLength = MinimumWordLengthMap[seed.length] ?? 4;

      // The algorithm returns multiple possible ladders that are
      // equally fit (or close to it)
      // We choose one at random to keep things lively and prevent
      // repeated sub-graphs
      final possibleLadders = getNextLevel(seed.toList(), minWordLength, index);
      return possibleLadders != null
          ? _pickRandom(possibleLadders, index)
          : null;
    } finally {
      _log("Done building ladder for $seed", LogLevel.Verbose);
    }
  }

  LadderLevel? _pickRandom(
      List<LadderLevel?>? possibleLadders, int randomSeed) {
    if (possibleLadders == null || possibleLadders.length == 0) {
      return null;
    }
    final index = Random(randomSeed).nextInt(possibleLadders.length);
    return possibleLadders[index];
  }

  List<LadderLevel?>? getNextLevel(
      List<String> current, int minWordLength, int randomSeed) {
    final joinedLetters = current.join();

    // Use cache only if the letters are not too short since in that
    // case we want to randomize a bit
    if (current.length > minWordLength + LevelsToRandomize &&
        _ladderCache.containsKey(joinedLetters)) {
      return _ladderCache[joinedLetters];
    }

    final requiredWords =
        (_requiredLetterTrie![joinedLetters] ?? Set.identity()).toList();
    final allWords =
        (_allLetterTrie![joinedLetters] ?? Set.identity()).toList();

    if (current.length == minWordLength) {
      if (requiredWords.length == 0) {
        return null; // let the next level be the bottom
      }
      final bottom = [LadderLevel.bottom(current, allWords.length, allWords)];
      _ladderCache[joinedLetters] = bottom;
      return bottom;
    }

    List<LadderLevel?>? bestLevels;
    final combos = _getCombinations(current)
        .where((element) => element.length == current.length - 1);

    // If we are with small letters, don't use the most words possible
    // heurtistic since it will lead to many of the same begining words
    // Just choose randomly

    if (current.length <= minWordLength + LevelsToRandomize) {
      // Shuffle the order and take the first one that has a next level
      final randomOrderCombos = combos.toList()..shuffle();
      for (final combo in randomOrderCombos) {
        var newLevels = getNextLevel(combo, minWordLength, randomSeed);
        if (newLevels != null) {
          bestLevels = newLevels;
          break;
        }
      }
    } else {
      // Find all sub-ladders that have same max word count
      final bestMap = Map<int, List<LadderLevel?>>();
      int maxWordCount = -1;
      int secondMaxWordCount = -1;
      for (final combo in combos) {
        var newLevels = getNextLevel(combo, minWordLength, randomSeed);
        final newLevel = _pickRandom(newLevels, randomSeed);
        if (newLevel == null) {
          continue;
        }

        if (bestMap[newLevel.levelWordCount] == null) {
          bestMap[newLevel.levelWordCount] = List.empty(growable: true);
        }
        bestMap[newLevel.levelWordCount]!.add(newLevel);
        if (newLevel.levelWordCount > maxWordCount) {
          secondMaxWordCount = max(secondMaxWordCount, maxWordCount);
        }
        maxWordCount = max(maxWordCount, newLevel.levelWordCount);
      }

      bestLevels = bestMap[maxWordCount];
      if (secondMaxWordCount > 0) {
        bestLevels!.addAll(bestMap[secondMaxWordCount]!);
      }
    }

    // If this level has no words we will skip the level
    if (requiredWords.length <= 0) {
      _ladderCache[joinedLetters] = bestLevels ?? List.empty(growable: true);
      return bestLevels;
    } else {
      // If null then this must be a new bottom (since nothing below was )
      if (bestLevels == null || bestLevels.isEmpty) {
        //_log("Non4 with $joinedLetters", LogLevel.Info);
        final bottom = [LadderLevel.bottom(current, allWords.length, allWords)];
        _ladderCache[joinedLetters] = bottom;
        return bottom;
      } else {
        final ladders = bestLevels
            .map((b) => LadderLevel(current, allWords.length, b!, allWords))
            .toList();
        _ladderCache[joinedLetters] = ladders;
        return ladders;
      }
    }
  }

  Future<void> processRawWords() async {
    // All words is full set that we allow a user to input
    Set<String> allWords = Set();

    // Seed are the sets of letters we allow for seeds
    Set<String> seedCandidates = Set();

    // Required are the words that are required at any rung in the ladder
    // We will allow more but require at least a more common word
    Set<String> requiredWords = Set();

    for (final name in scowlEasyFileNames) {
      final scowlPath = getScowlFile(name);
      final tempWords = await linesFromFile(scowlPath);
      allWords.addAll(tempWords);
      requiredWords.addAll(tempWords);

      for (final tempWord in tempWords) {
        var letters = tempWord.toList(mutable: true)..sort();
        final wordLetters = letters.join();
        seedCandidates.add(wordLetters);
      }
    }
    for (final name in scowlMediumFileNames) {
      final scowlPath = getScowlFile(name);
      final tempWords = await linesFromFile(scowlPath);
      allWords.addAll(tempWords);
      requiredWords.addAll(tempWords);
    }
    for (final name in scowlHardFileNames) {
      final scowlPath = getScowlFile(name);
      final tempWords = await linesFromFile(scowlPath);
      allWords.addAll(tempWords);
    }

    List<String> blacklistRaw = await linesFromFile(BlackListFilePath);
    Set<String> blacklist = Set.from(blacklistRaw);

    List<String> wordList1 = await linesFromFile(NounListPath);
    List<String> wordList2 = await linesFromFile(ExtraWordFilePath);
    allWords..addAll(wordList1)..addAll(wordList2);
    requiredWords..addAll(wordList1)..addAll(wordList2);

    final wordsByLength = allWords
        .where((word) => !blacklist.contains(word))
        .toList()
          ..sort((a, b) => b.length - a.length);

    File allWordFile = File(ProcessWordFilePath);
    File requiredWordFile = File(RequiredWordFilePath);
    File seedLetterSetFile = File(SeedLetterSetPath);
    IOSink allWordWriter, requiredWordWriter, seedLetterSetWriter;
    int count = 0;
    int requiredWordCount = 0;
    int maxLen = 0;
    Map<int, int> dist = {};
    Set<String> seedLetterSets = Set.identity();
    final trie =
        Trie<String, String, String>.fromIterable([], parts: (p) => p.toList());

    try {
      allWordWriter = allWordFile.openWrite();
      requiredWordWriter = requiredWordFile.openWrite();
      for (var word in wordsByLength) {
        if (word.length < MinimumWordLength ||
            word.length > SeedWordLengthMax) {
          continue;
        }
        if (word.contains("'")) {
          continue;
        }

        if (word.length >= SeedWordLengthMin &&
            word.length <= SeedWordLengthMax) {
          var letters = word.toList(mutable: true)..sort();
          final wordLetters = letters.join();

          // Prevent duplicates so we never have a final word appear
          // in the ladder of another word
          if (seedCandidates.contains(wordLetters) &&
              trie.entriesWithPrefix(wordLetters).isEmpty) {
            trie[wordLetters] = wordLetters;
            seedLetterSets.add(wordLetters);
          }
        }

        if (!dist.containsKey(word.length)) {
          dist[word.length] = 1;
        } else {
          dist[word.length] = dist[word.length]! + 1;
        }

        count++;
        maxLen = max(word.length, maxLen);

        allWordWriter.writeln(word);
        if (requiredWords.contains(word)) {
          requiredWordWriter.writeln(word);
          requiredWordCount++;
        }
      }
      await allWordWriter.close();
      await allWordWriter.done;
      await requiredWordWriter.close();
      await requiredWordWriter.done;

      // Write seeds
      final shuffledSeeds = seedLetterSets.toList()..shuffle(_random);
      seedLetterSetWriter = seedLetterSetFile.openWrite();
      for (var item in shuffledSeeds) {
        seedLetterSetWriter.writeln(item);
      }
      await seedLetterSetWriter.close();
      await seedLetterSetWriter.done;
    } catch (error) {
      print("Failed due to ${error.toString()}");
    } finally {}

    print("Stats");
    print("Max Length = $maxLen");
    print("Required Word Count = $requiredWordCount");
    print("Total Word Count = $count");
    print("Word Sets = ${seedLetterSets.length}");
    print("Distribution");
    final keys = dist.keys.toList()..sort();
    for (var key in keys) {
      final item = dist[key];
      print("Length:$key has count $item");
    }
  }

  static Future writeLadderFile(int length, List<LadderLevel> levels) async {
    final path = getGameLadderSetPath(length);

    var file = File(path);
    final writer = file.openWrite();
    writer.writeln("[");
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      var json = level.toJson();
      writer.write(jsonEncode(json));
      if (i < levels.length - 1) {
        writer.writeln(",");
      } else {
        writer.writeln();
      }
    }

    writer.write("]");
    await writer.close();
    await writer.done;
  }
}
