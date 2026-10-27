import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:anagram_ladder/anagram/anagramBuilder.dart';
import 'package:anagram_ladder/anagram/ladderLevel.dart';

import 'vocabulary.dart';

const publishedDirectory = 'tools/langs/en/processed';
const catalogLockPath = 'tools/langs/en/catalog.lock.json';
const catalogExceptionsPath = 'tools/langs/en/catalog-exceptions.json';
const sourceLockPath = 'tools/langs/en/sources.lock.json';

Future<Map<int, List<LadderLevel>>> loadCatalog(String directory) async => {
  for (final length in AnagramLadderBuilder.MinimumWordLengthMap.keys)
    length:
        (jsonDecode(
              await File('$directory/ladders_$length.json').readAsString(),
            ) as List)
            .map((entry) => LadderLevel.fromJson(entry as Map<String, dynamic>))
            .toList(),
};

void validateCatalog(
  Map<int, List<LadderLevel>> catalog,
  Vocabulary vocabulary,
) {
  final letter = RegExp(r'^[a-z]$');
  final word = RegExp(r'^[a-z]{4,10}$');
  void check(bool valid, String reason) {
    if (!valid) throw StateError(reason);
  }

  check(catalog.length == 5, 'Expected all five difficulties');
  for (final length in AnagramLadderBuilder.MinimumWordLengthMap.keys) {
    final ladders = catalog[length];
    check(
      ladders != null && ladders.length == 250,
      'Expected 250 ladders for $length',
    );
    final used = <String>{};
    for (var index = 0; index < ladders!.length; index++) {
      final top = ladders[index];
      final id = '$length/${index + 1}';
      check(top.letterCount == length, '$id: wrong top length');
      check(used.add(sortedLetters(top.letters.join())), '$id: duplicate seed');
      final rungs = top.getBottomUp();
      check(rungs.length >= 3, '$id: fewer than three rungs');
      check(
        rungs.first.letterCount >= AnagramLadderBuilder.MinimumWordLength,
        '$id: bottom too short',
      );
      for (final rung in rungs) {
        check(rung.letters.every(letter.hasMatch), '$id: non-ASCII tile');
        check(
          rung.lettersToAdd.every(letter.hasMatch),
          '$id: non-ASCII added tile',
        );
        check(
          rung.letters.join() == sortedLetters(rung.letters.join()),
          '$id: unsorted letters',
        );
        check(
          rung.words.isNotEmpty &&
              rung.words.toSet().length == rung.words.length,
          '$id: empty or duplicate answers',
        );
        check(
          rung.words.any(vocabulary.required.contains),
          '$id: no familiar answer',
        );
        check(
          rung.levelWordCount == rung.words.length,
          '$id: wrong word count',
        );
        for (final answer in rung.words) {
          check(
            word.hasMatch(answer) && vocabulary.words.contains(answer),
            '$id: invalid answer $answer',
          );
          check(
            sortedLetters(answer) == rung.letters.join(),
            '$id: answer letters do not match',
          );
        }
        final child = rung.childLevel;
        check(
          rung.rung == (child == null ? 0 : child.rung + 1),
          '$id: wrong rung count',
        );
        check(
          rung.totalWordCount ==
              rung.words.length + (child?.totalWordCount ?? 0),
          '$id: wrong total word count',
        );
        if (child == null) {
          check(rung.lettersToAdd.isEmpty, '$id: bottom adds letters');
        } else {
          check(rung.letterCount > child.letterCount, '$id: rungs do not grow');
          check(
            sortedLetters([...child.letters, ...rung.lettersToAdd].join()) ==
                rung.letters.join(),
            '$id: inconsistent letter additions',
          );
        }
      }
    }
  }
}

Map<String, Object> catalogSnapshot(Map<int, List<LadderLevel>> catalog) => {
  'schema': 1,
  'immutableLevels': 50,
  'ladders': {
    for (final length in AnagramLadderBuilder.MinimumWordLengthMap.keys)
      '$length': catalog[length]!
          .map((ladder) => fingerprint(ladder.toJson()))
          .toList(),
  },
};

Future<List<Map<String, Object>>> compatibilityChanges(
  Map<int, List<LadderLevel>> catalog, {
  String lockPath = catalogLockPath,
  String exceptionsPath = catalogExceptionsPath,
}) async {
  final lock =
      jsonDecode(await File(lockPath).readAsString()) as Map<String, dynamic>;
  final hashes = lock['ladders'] as Map<String, dynamic>;
  final exceptions =
      jsonDecode(await File(exceptionsPath).readAsString()) as List;
  final approvals = <String, Map>{};
  for (final value in exceptions) {
    final approval = value as Map;
    final world = approval['world'];
    final level = approval['level'];
    // The user explicitly approved this one free-level repair.
    final approvedNormal49 =
        world == 6 &&
        level == 49 &&
        approval['before'] ==
            'e9b7960c5ac35a97d0b87eec165f0579edacf4f91c46d062cc7231dcdee707dd' &&
        approval['after'] ==
            '5b799c290929576c547a686b3ceb03c43b8ea2593528236305b0ac66d7603fca';
    if (world is! int ||
        !AnagramLadderBuilder.MinimumWordLengthMap.containsKey(world) ||
        level is! int ||
        level < 1 ||
        (level <= 50 && !approvedNormal49) ||
        level > 250 ||
        approval['reason'] is! String ||
        (approval['reason'] as String).trim().isEmpty ||
        approval['migration'] is! String ||
        (approval['migration'] as String).trim().isEmpty ||
        approval['before'] is! String ||
        approval['after'] is! String ||
        approvals.containsKey('$world/$level')) {
      throw FormatException('Invalid catalog exception: $approval');
    }
    approvals['$world/$level'] = approval;
  }
  if (lock['schema'] != 1 ||
      lock['immutableLevels'] != 50 ||
      hashes.length != 5) {
    throw const FormatException('Invalid catalog lock');
  }
  final changes = <Map<String, Object>>[];
  for (final world in AnagramLadderBuilder.MinimumWordLengthMap.keys) {
    final expected = hashes['$world'] as List;
    if (expected.length != 250 || catalog[world]?.length != 250) {
      throw StateError('Catalog count changed for $world');
    }
    for (var index = 0; index < expected.length; index++) {
      final after = fingerprint(catalog[world]![index].toJson());
      final approval = approvals['$world/${index + 1}'];
      if (approval != null &&
          (approval['before'] != expected[index] ||
              approval['after'] != after)) {
        throw StateError('Stale catalog exception for $world/${index + 1}');
      }
      if (after == expected[index]) continue;
      changes.add({
        'world': world,
        'level': index + 1,
        'before': expected[index],
        'after': after,
        'approved': approval != null,
        'immutable': index < 50,
      });
    }
  }
  return changes;
}

Map<String, String> catalogFiles(Map<int, List<LadderLevel>> catalog) => {
  for (final entry in catalog.entries)
    'ladders_${entry.key}.json':
        '[\n${entry.value.map((ladder) => jsonEncode(ladder.toJson())).join(',\n')}\n]',
};

Future<Map<String, Object>> compareCatalogs(
  Map<int, List<LadderLevel>> candidate,
  Map<int, List<LadderLevel>> previous,
) async => {
  'changed': [
    for (final world in AnagramLadderBuilder.MinimumWordLengthMap.keys)
      for (var index = 0; index < candidate[world]!.length; index++)
        if (fingerprint(candidate[world]![index].toJson()) !=
            fingerprint(previous[world]![index].toJson()))
          {
            'world': world,
            'level': index + 1,
            'oldRungs': previous[world]![index].getBottomUp().length,
            'newRungs': candidate[world]![index].getBottomUp().length,
            'before': previous[world]![index].toJson(),
            'after': candidate[world]![index].toJson(),
          },
  ],
};

Future<void> writeCandidate(String path, Map<String, String> files) async {
  final destination = Directory(path).absolute;
  if (await FileSystemEntity.type(destination.path) !=
      FileSystemEntityType.notFound) {
    throw StateError('Output already exists: ${destination.path}');
  }
  await destination.parent.create(recursive: true);
  final staging = await destination.parent.createTemp('.ladder-candidate-');
  try {
    for (final entry in files.entries) {
      if (entry.key.contains('/') ||
          entry.key.contains('\\') ||
          entry.key.startsWith('.')) {
        throw ArgumentError('Invalid candidate filename: ${entry.key}');
      }
      await File('${staging.path}/${entry.key}')
          .writeAsString(entry.value, flush: true);
    }
    await staging.rename(destination.path);
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}

Future<void> verifySources({String path = sourceLockPath}) async {
  final lock =
      jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
  final files = lock['files'] as Map<String, dynamic>;
  final declared = _sourcePaths().toSet();
  final scowl = (lock['legacy'] as Map?)?['scowl'] as Map?;
  if (lock['schema'] != 1 ||
      files.length != declared.length ||
      !declared.containsAll(files.keys) ||
      jsonEncode(scowl?['requiredAndSeeds']) !=
          jsonEncode(AnagramLadderBuilder.scowlEasyFileNames) ||
      jsonEncode(scowl?['additionalAccepted']) !=
          jsonEncode(AnagramLadderBuilder.scowlHardFileNames)) {
    throw StateError(
      'Source lock does not match the declared inputs and roles',
    );
  }
  for (final entry in files.entries) {
    final actual = sha256
        .convert(await File(entry.key).readAsBytes())
        .toString();
    if (actual != entry.value)
      throw StateError('Source checksum mismatch: ${entry.key}');
  }
}

List<Map<String, Object>> vocabularyConflicts(
  Map<int, List<LadderLevel>> catalog,
  Vocabulary vocabulary,
) => [
  for (final entry in catalog.entries)
    for (var index = 0; index < entry.value.length; index++)
      for (final rung in entry.value[index].getBottomUp())
        if (rung.words.any((word) => !vocabulary.words.contains(word)) ||
            !rung.words.any(vocabulary.required.contains))
          {
            'world': entry.key,
            'level': index + 1,
            'letters': rung.letters.join(),
            'missingAnswers': rung.words
                .where((word) => !vocabulary.words.contains(word))
                .toList(),
            'missingFamiliarAnswer': !rung.words.any(
              vocabulary.required.contains,
            ),
          },
];

List<String> _sourcePaths() => [
  for (final name in [
    ...AnagramLadderBuilder.scowlEasyFileNames,
    ...AnagramLadderBuilder.scowlHardFileNames,
    'readme.md',
    'Copyright',
  ])
    AnagramLadderBuilder.getScowlFile(name),
  AnagramLadderBuilder.NounListPath,
  'tools/langs/en/raw/GreatNounList/readme.md',
  AnagramLadderBuilder.BlackListFilePath,
  AnagramLadderBuilder.ExtraWordFilePath,
]..sort();

Future<Map<String, Object>> sourceSnapshot() async {
  final paths = _sourcePaths();
  return {
    'schema': 1,
    'legacy': {
      'repositorySnapshot': '9ece3a6',
      'scowl': {
        'url': 'https://wordlist.aspell.net/',
        'release': 'Unknown in original import; local bytes are pinned, not claimed to match a particular upstream release.',
        'license': 'MIT-like with component notices; see raw/Scowl/Copyright',
        'licenseReference': 'https://github.com/en-wl/wordlist/blob/b22230cc5250887737fdefe9ca4c9d9d01230eaa/scowl/Copyright',
        'requiredAndSeeds': AnagramLadderBuilder.scowlEasyFileNames,
        'additionalAccepted': AnagramLadderBuilder.scowlHardFileNames,
      },
      'nouns': {
        'url': 'https://www.desiquintans.com/nounlist',
        'license': 'Public domain, as stated on the source page',
        'release': 'Original imported bytes; upstream page describes 6,775 nouns, last modified 2019-02-10.',
      },
      'localOverrides': ['raw/extra_words.txt', 'raw/blacklist.txt'],
      'normalization': 'Trim and lowercase; reject non-ASCII, punctuation, replacement characters and lengths outside 4-10. No guessed transliteration.',
      'seedPolicy': 'Unique sorted multisets from familiar SCOWL words of length 6-10. Nested multisets are allowed.',
      'hintPolicy': 'Retain bundled 10/20/35 SCOWL ranks. New vocabulary alone does not change hint selection.',
    },
    'esdbEvaluation': {
      'revision': '1e5b7d3a72f47a71da5d28686c1dd4b397178485',
      'url': 'https://github.com/en-wl/wordlist',
      'archiveUrl': 'https://codeload.github.com/en-wl/wordlist/tar.gz/1e5b7d3a72f47a71da5d28686c1dd4b397178485',
      'archiveSha256':
          'aaecc7a54af576057e30b22a19b78bad011f2181f7e368ff3b736fbecbdfd4d0',
      'license': 'MIT-like; retain upstream Copyright before distributing derived vocabulary',
      'licenseUrl': 'https://github.com/en-wl/wordlist/blob/1e5b7d3a72f47a71da5d28686c1dd4b397178485/Copyright',
      'requiredCommand':
          './scowl word-list 35 A 1 --deaccent --wo-poses=abbr --categories=',
      'allowedCommand':
          './scowl word-list 70 A 1 --deaccent --wo-poses=abbr --categories=',
      'exportPostprocessing': 'LC_ALL=C sort -u; UTF-8, LF-terminated. Application preprocessing rejects non-lowercase-ASCII and out-of-range words.',
      'requiredSha256':
          'ce4c6d0c7249b8792e815180ce0b000f821f2067e5e8991dec3645c7f42e141a',
      'allowedSha256':
          '249e3d26db2e8f7fccb8b9765c0effd9b9d875cacbe486adabbef8120ea3db8b',
      'adopted': false,
      'hintCaveat': 'ESDB minimum size is 35, so it cannot replace the existing 10/20/35 hint ranking unchanged.',
    },
    'files': {
      for (final path in paths)
        path: sha256.convert(await File(path).readAsBytes()).toString(),
    },
  };
}

Future<String> verifyEsdbExports(
  Map<String, String> exports, {
  String path = sourceLockPath,
}) async {
  final lock = jsonDecode(await File(path).readAsString()) as Map;
  final evaluation = lock['esdbEvaluation'] as Map;
  for (final role in ['required', 'allowed']) {
    final actual = sha256
        .convert(await File(exports[role]!).readAsBytes())
        .toString();
    if (actual != evaluation['${role}Sha256']) {
      throw StateError(
        'ESDB $role export does not match pinned revision and settings',
      );
    }
  }
  return evaluation['revision'] as String;
}

Future<void> publishCandidate(
  String candidateDirectory, {
  String destination = publishedDirectory,
  String lockPath = catalogLockPath,
  String exceptionsPath = catalogExceptionsPath,
}) async {
  final candidate = await loadCatalog(candidateDirectory);
  final vocabulary = await Vocabulary.load(candidateDirectory);
  validateCatalog(candidate, vocabulary);
  final changes = await compatibilityChanges(
    candidate,
    lockPath: lockPath,
    exceptionsPath: exceptionsPath,
  );
  if (changes.any((change) => change['approved'] != true)) {
    throw StateError(
      'Publication blocked by catalog compatibility: ${jsonEncode(changes)}',
    );
  }
  final target = Directory(destination).absolute;
  final source = Directory(candidateDirectory).absolute;
  if (source.path == target.path || source.path.startsWith('${target.path}/')) {
    throw ArgumentError('Candidate must be outside the published directory');
  }
  if (!await target.exists())
    throw StateError('Published directory does not exist');
  final backup = Directory('${target.path}.publish-backup');
  if (await FileSystemEntity.type(backup.path) !=
      FileSystemEntityType.notFound) {
    throw StateError(
      'Unfinished publication: recover ${backup.path} before retrying',
    );
  }
  final staging = await target.parent.createTemp('.ladder-publish-');
  try {
    // Preserve auxiliary files, but never follow symlinks during publication.
    await for (final entity in target.list(followLinks: false)) {
      if (entity is! File)
        throw StateError('Unexpected published entry: ${entity.path}');
      await entity.copy('${staging.path}/${entity.uri.pathSegments.last}');
    }
    final vocabularyFiles = <String, String>{};
    for (final entry in vocabulary.files.entries) {
      final remaining = const LineSplitter().convert(entry.value).toSet();
      final previous = File('${target.path}/${entry.key}');
      final ordered = <String>[
        if (await previous.exists())
          for (final word in await previous.readAsLines())
            if (remaining.remove(word)) word,
        ...(remaining.toList()..sort()),
      ];
      vocabularyFiles[entry.key] = '${ordered.join('\n')}\n';
    }
    for (final entry in {
      ...vocabularyFiles,
      ...catalogFiles(candidate),
    }.entries) {
      await File('${staging.path}/${entry.key}')
          .writeAsString(entry.value, flush: true);
    }
    // Both renames stay on the same filesystem. Retain a recovery copy until
    // installation succeeds; command failures restore the previous directory.
    await target.rename(backup.path);
    try {
      await staging.rename(target.path);
    } catch (_) {
      await backup.rename(target.path);
      rethrow;
    }
    await backup.delete(recursive: true);
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}
