import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:anagram_ladder/anagram/anagramBuilder.dart';

String sortedLetters(String word) => (word.split('')..sort()).join();
String fingerprint(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

class Vocabulary {
  final Set<String> words;
  final Set<String> required;
  final Set<String> seeds;

  Vocabulary(this.words, this.required, this.seeds);

  static Future<Vocabulary> load(
    String directory, {
    bool legacy = false,
  }) async {
    Future<Set<String>> read(String name, int minimum) async {
      final lines = await File('$directory/$name').readAsLines();
      final valid = RegExp('^[a-z]{$minimum,10}\$');
      if (!legacy &&
          (lines.any((line) => !valid.hasMatch(line)) ||
              lines.toSet().length != lines.length)) {
        throw FormatException(
          'Malformed or duplicate entries in $directory/$name',
        );
      }
      return lines.where(valid.hasMatch).toSet();
    }

    final vocabulary = Vocabulary(
      await read('words.txt', 4),
      await read('requiredWords.txt', 4),
      await read('seedLetterSets.txt', 6),
    );
    vocabulary.validate();
    return vocabulary;
  }

  void validate() {
    if (words.isEmpty || required.isEmpty || seeds.isEmpty) {
      throw StateError(
        'Vocabulary, familiar words and seeds must not be empty',
      );
    }
    if (!words.containsAll(required)) {
      throw StateError('Familiar words must be a subset of allowed words');
    }
    if (words.any((word) => !RegExp(r'^[a-z]{4,10}$').hasMatch(word)) ||
        seeds.any((seed) => !RegExp(r'^[a-z]{6,10}$').hasMatch(seed))) {
      throw const FormatException('Vocabulary contains non-playable entries');
    }
    final requiredSeeds = required.map(sortedLetters).toSet();
    if (seeds.any(
      (seed) => seed != sortedLetters(seed) || !requiredSeeds.contains(seed),
    )) {
      throw StateError('Seeds must be sorted letter sets of familiar words');
    }
  }

  Map<String, String> get files => {
    'words.txt': _lines(words),
    'requiredWords.txt': _lines(required),
    'seedLetterSets.txt': _lines(seeds),
  };

  static String _lines(Set<String> entries) =>
      '${(entries.toList()..sort()).join('\n')}\n';

  Map<String, Object> compare(Vocabulary previous) {
    Map<String, Object> changes(Set<String> before, Set<String> after) => {
      'added': after.difference(before).toList()..sort(),
      'removed': before.difference(after).toList()..sort(),
      'count': after.length,
    };
    return {
      'words': changes(previous.words, words),
      'requiredWords': changes(previous.required, required),
      'seeds': changes(previous.seeds, seeds),
    };
  }
}

class VocabularyBuild {
  final Vocabulary vocabulary;
  final Map<String, Object> report;
  VocabularyBuild(this.vocabulary, this.report);
}

Future<VocabularyBuild> processVocabulary({
  String rawDirectory = 'tools/langs/en/raw',
  Map<String, String>? scowlExports,
}) async {
  final exclusions = <Map<String, Object>>[];
  final normalizations = <Map<String, Object>>[];
  final sources = <String, String>{};
  var duplicates = 0;

  Future<Set<String>> read(String relative) async {
    final file = File('$rawDirectory/$relative');
    final bytes = await file.readAsBytes();
    sources[relative] = sha256.convert(bytes).toString();
    // Strict UTF-8 decoding fails before any output is written.
    final lines = const LineSplitter().convert(utf8.decode(bytes));
    final result = <String>{};
    for (var index = 0; index < lines.length; index++) {
      final raw = lines[index];
      final word = raw.trim().toLowerCase();
      String? reason;
      if (word.contains('\uFFFD')) {
        reason = 'replacement-character';
      } else if (word.isEmpty) {
        reason = 'blank';
      } else if (!RegExp(r'^[a-z]+$').hasMatch(word)) {
        reason = 'non-ascii-or-punctuation';
      } else if (word.length < 4 || word.length > 10) {
        reason = 'outside-4-to-10-letters';
      }
      if (reason != null) {
        exclusions.add({
          'source': relative,
          'line': index + 1,
          'word': raw,
          'reason': reason,
        });
        continue;
      }
      if (word != raw) {
        normalizations.add({
          'source': relative,
          'line': index + 1,
          'before': raw,
          'after': word,
        });
      }
      if (!result.add(word)) duplicates++;
    }
    return result;
  }

  final words = <String>{};
  final required = <String>{};
  final seeds = <String>{};
  if (scowlExports == null) {
    for (final name in AnagramLadderBuilder.scowlEasyFileNames) {
      final entries = await read('Scowl/$name');
      words.addAll(entries);
      required.addAll(entries);
      seeds.addAll(
        entries.where((word) => word.length >= 6).map(sortedLetters),
      );
    }
    for (final name in AnagramLadderBuilder.scowlHardFileNames) {
      words.addAll(await read('Scowl/$name'));
    }
  } else {
    for (final role in ['required', 'allowed']) {
      final path = scowlExports[role];
      if (path == null) throw ArgumentError('Missing $role ESDB export');
      final bytes = await File(path).readAsBytes();
      sources['esdb-$role'] = sha256.convert(bytes).toString();
      final entries = <String>{};
      final lines = const LineSplitter().convert(utf8.decode(bytes));
      for (var index = 0; index < lines.length; index++) {
        final word = lines[index];
        if (RegExp(r'^[a-z]{4,10}$').hasMatch(word)) {
          entries.add(word);
        } else {
          exclusions.add({
            'source': path,
            'line': index + 1,
            'word': word,
            'reason': 'esdb-non-playable',
          });
        }
      }
      words.addAll(entries);
      if (role == 'required') {
        required.addAll(entries);
        seeds.addAll(
          entries.where((word) => word.length >= 6).map(sortedLetters),
        );
      }
    }
  }
  for (final path in ['GreatNounList/noun_list.txt', 'extra_words.txt']) {
    final entries = await read(path);
    words.addAll(entries);
    required.addAll(entries);
  }
  final blacklist = await read('blacklist.txt');
  for (final word in words.intersection(blacklist).toList()..sort()) {
    exclusions.add({
      'source': 'blacklist.txt',
      'word': word,
      'reason': 'blacklisted',
    });
  }
  words.removeAll(blacklist);
  required.removeAll(blacklist);
  final eligible = required.map(sortedLetters).toSet();
  seeds.removeWhere((seed) => !eligible.contains(seed));
  final vocabulary = Vocabulary(words, required, seeds)..validate();
  return VocabularyBuild(vocabulary, {
    'policy': 'lowercase ASCII, 4-10 letters; unique seed multisets, not disjoint subsets',
    'sources': sources,
    'duplicatesWithinSources': duplicates,
    'normalizations': normalizations,
    'exclusions': exclusions,
    'counts': {
      'words': words.length,
      'required': required.length,
      'seeds': seeds.length,
    },
    'hintPolicy': 'Retain bundled SCOWL 10/20/35 hint ranks. ESDB has no equivalent 10/20 tiers.',
  });
}
