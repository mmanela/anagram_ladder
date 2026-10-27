import 'dart:convert';
import 'dart:io';

import 'package:anagram_ladder/anagram/anagramBuilder.dart';
import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';

import '../tools/ladder_pipeline.dart';
import '../tools/main.dart' as cli;
import '../tools/vocabulary.dart';

void main() {
  late Directory temporary;
  late Map<int, List<LadderLevel>> catalog;
  late Vocabulary vocabulary;
  late VocabularyBuild cleaned;

  setUpAll(() async {
    cleaned = await processVocabulary();
  });

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('ladder-pipeline-test-');
    catalog = await loadCatalog(publishedDirectory);
    vocabulary = cleaned.vocabulary;
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  int reverseAnswers({required bool paid}) {
    final index = catalog[6]!.indexWhere(
      (ladder) => ladder.words.length > 1,
      paid ? 50 : 0,
    );
    expect(index, greaterThanOrEqualTo(0));
    if (!paid) expect(index, lessThan(50));
    final words = catalog[6]![index].words;
    words.setAll(0, words.reversed.toList());
    return index;
  }

  Future<String> approvals(List<Map<String, Object>> values) async {
    final file = File('${temporary.path}/exceptions.json');
    final published =
        jsonDecode(await File(catalogExceptionsPath).readAsString()) as List;
    await file.writeAsString(jsonEncode([...published, ...values]));
    return file.path;
  }

  Future<String> candidate() async {
    final path = '${temporary.path}/candidate';
    await writeCandidate(path, {...vocabulary.files, ...catalogFiles(catalog)});
    return path;
  }

  test(
    'all published content matches its independent compatibility baseline',
    () async {
      validateCatalog(catalog, vocabulary);
      final published = await Vocabulary.load(publishedDirectory);
      for (final pair in [
        (published.words, vocabulary.words),
        (published.required, vocabulary.required),
        (published.seeds, vocabulary.seeds),
      ]) {
        expect(pair.$1.length, pair.$2.length);
        expect(pair.$1.containsAll(pair.$2), isTrue);
      }
      final changes = await compatibilityChanges(catalog);
      expect(changes, hasLength(6));
      expect(
        changes.map((change) => (change['world'], change['level'])),
        unorderedEquals([
          (6, 49),
          (6, 144),
          (9, 136),
          (9, 245),
          (10, 96),
          (10, 100),
        ]),
      );
      expect(changes.map((change) => change['approved']), everyElement(isTrue));
      expect(
        changes.where((change) => change['immutable'] == true).single['level'],
        49,
      );
      final lock =
          jsonDecode(await File(catalogLockPath).readAsString()) as Map;
      expect(lock['immutableLevels'], 50);
      expect((lock['ladders'] as Map).values, everyElement(hasLength(250)));
    },
  );

  test(
    'even valid answer reordering in levels 1-50 blocks publication',
    () async {
      final index = reverseAnswers(paid: false);
      validateCatalog(catalog, vocabulary);
      final changes = await compatibilityChanges(catalog);
      expect(changes, hasLength(7));
      final protected = changes.singleWhere(
        (change) => change['world'] == 6 && change['level'] == index + 1,
      );
      expect(protected['level'], index + 1);
      expect(protected['immutable'], isTrue);
      final target = '${temporary.path}/published';
      await writeCandidate(target, {'sentinel.txt': 'unchanged'});
      await expectLater(
        publishCandidate(await candidate(), destination: target),
        throwsStateError,
      );
      expect(await File('$target/sentinel.txt').readAsString(), 'unchanged');
      expect(await Directory('$target.publish-backup').exists(), isFalse);
    },
  );

  test(
    'paid changes require exact before/after hashes and migration notes',
    () async {
      final index = reverseAnswers(paid: true);
      final change = (await compatibilityChanges(catalog)).singleWhere(
        (change) => change['world'] == 6 && change['level'] == index + 1,
      );
      expect(change['approved'], isFalse);
      final approved = {
        'world': 6,
        'level': index + 1,
        'before': change['before']!,
        'after': change['after']!,
        'reason': 'Answer ordering only',
        'migration': 'No tile or answer changes; saved rows remain valid.',
      };
      final path = await approvals([approved]);
      expect(
        (await compatibilityChanges(catalog, exceptionsPath: path)).singleWhere(
          (change) => change['world'] == 6 && change['level'] == index + 1,
        )['approved'],
        isTrue,
      );
      final target = '${temporary.path}/published';
      await writeCandidate(target, {
        'sentinel.txt': 'retained',
        'words.txt': 'script\nrips\n',
      });
      await publishCandidate(
        await candidate(),
        destination: target,
        exceptionsPath: path,
      );
      expect(await File('$target/sentinel.txt').readAsString(), 'retained');
      expect((await File('$target/words.txt').readAsLines()).take(2), [
        'script',
        'rips',
      ]);
      expect(
        await compatibilityChanges(
          await loadCatalog(target),
          exceptionsPath: path,
        ),
        hasLength(7),
      );
      expect(await Directory('$target.publish-backup').exists(), isFalse);
      await approvals([
        {...approved, 'after': 'wrong-hash'},
      ]);
      await expectLater(
        compatibilityChanges(catalog, exceptionsPath: path),
        throwsStateError,
      );
      await approvals([
        {...approved, 'migration': ''},
      ]);
      await expectLater(
        compatibilityChanges(catalog, exceptionsPath: path),
        throwsFormatException,
      );
    },
  );

  test('an exception cannot authorize changing a protected puzzle', () async {
    final index = reverseAnswers(paid: false);
    final change = (await compatibilityChanges(catalog)).singleWhere(
      (change) => change['world'] == 6 && change['level'] == index + 1,
    );
    final path = await approvals([
      {
        'world': 6,
        'level': index + 1,
        'before': change['before']!,
        'after': change['after']!,
        'reason': 'Not permitted',
        'migration': 'Not permitted',
      },
    ]);
    await expectLater(
      compatibilityChanges(catalog, exceptionsPath: path),
      throwsFormatException,
    );
  });

  test('Normal 49 approval cannot authorize another candidate', () async {
    final words = catalog[6]![48].words;
    words.setAll(0, words.reversed.toList());
    await expectLater(compatibilityChanges(catalog), throwsStateError);
    final changes = await compatibilityChanges(
      catalog,
      requireMatchingApprovals: false,
    );
    final normal49 = changes.singleWhere(
      (change) => change['world'] == 6 && change['level'] == 49,
    );
    expect(normal49['approved'], isFalse);
    expect(normal49['immutable'], isTrue);
    expect(
      changes
          .where((change) => change != normal49)
          .map((change) => change['approved']),
      everyElement(isTrue),
    );
    final path = await candidate();
    await expectLater(
      cli.run(['validate', '--candidate', path]),
      throwsStateError,
    );
    final target = '${temporary.path}/published';
    await writeCandidate(target, {'sentinel.txt': 'unchanged'});
    await expectLater(
      publishCandidate(path, destination: target),
      throwsStateError,
    );
    expect(await File('$target/sentinel.txt').readAsString(), 'unchanged');
  });

  test(
    'staging failures never leave partial output or overwrite existing files',
    () async {
      final path = '${temporary.path}/output';
      await expectLater(
        writeCandidate(path, {
          'first.txt': 'partial',
          '../escape.txt': 'invalid',
        }),
        throwsArgumentError,
      );
      expect(await Directory(path).exists(), isFalse);
      expect(await temporary.list().toList(), isEmpty);
      await writeCandidate(path, {'first.txt': 'original'});
      await expectLater(
        writeCandidate(path, {'first.txt': 'changed'}),
        throwsStateError,
      );
      expect(await File('$path/first.txt').readAsString(), 'original');
    },
  );

  test(
    'publication refuses incomplete recovery and preserves existing files',
    () async {
      final target = '${temporary.path}/published';
      await writeCandidate(target, {'sentinel.txt': 'original'});
      await Directory('$target.publish-backup').create();
      await expectLater(
        publishCandidate(await candidate(), destination: target),
        throwsStateError,
      );
      expect(await File('$target/sentinel.txt').readAsString(), 'original');
    },
  );

  test(
    'invalid candidate data is rejected before touching publication',
    () async {
      final target = '${temporary.path}/published';
      await writeCandidate(target, {'sentinel.txt': 'original'});
      catalog[6]![97].letters[5] = '\uFFFD';
      await expectLater(
        publishCandidate(await candidate(), destination: target),
        throwsStateError,
      );
      expect(await File('$target/sentinel.txt').readAsString(), 'original');
    },
  );

  test('vocabulary processing is deterministic and preserves all published answers', () async {
    final second = await processVocabulary();
    expect(second.vocabulary.files, vocabulary.files);
    expect(second.report, cleaned.report);
    expect(vocabularyConflicts(catalog, vocabulary), isEmpty);
    final exclusions =
        cleaned.report['exclusions'] as List<Map<String, Object>>;
    expect(
      exclusions.where((entry) => entry['reason'] == 'replacement-character'),
      isNotEmpty,
    );
    expect(vocabulary.words, everyElement(matches(r'^[a-z]{4,10}$')));
    expect(vocabulary.seeds, everyElement(matches(r'^[a-z]{6,10}$')));
    expect(vocabulary.seeds, containsAll(['aaabdest', 'aaabdesst']));
    validateCatalog(catalog, vocabulary);
  });

  test('source lock matches original input bytes', () async {
    await verifySources();
  });

  test(
    'changed source bytes and unpinned ESDB exports fail explicitly',
    () async {
      final raw = File('${temporary.path}/source.txt');
      await raw.writeAsString('changed');
      final lock = File('${temporary.path}/sources.lock.json');
      final original = jsonDecode(
        await File(sourceLockPath).readAsString(),
      ) as Map<String, dynamic>;
      final files = original['files'] as Map<String, dynamic>;
      files[files.keys.first] = 'incorrect';
      await lock.writeAsString(jsonEncode(original));
      await expectLater(verifySources(path: lock.path), throwsStateError);
      await expectLater(
        verifyEsdbExports({'required': raw.path, 'allowed': raw.path}),
        throwsStateError,
      );
    },
  );

  test('invalid UTF-8 input aborts processing without output', () async {
    final file = File('${temporary.path}/Scowl/american-words.10');
    await file.parent.create();
    await file.writeAsBytes([0xff]);
    await expectLater(
      processVocabulary(rawDirectory: temporary.path),
      throwsFormatException,
    );
    expect(await File('${temporary.path}/words.txt').exists(), isFalse);
  });

  test('ESDB verification checks both exported files and returns the pinned revision', () async {
    final required = File('${temporary.path}/required.txt');
    final allowed = File('${temporary.path}/allowed.txt');
    await required.writeAsString('required\n');
    await allowed.writeAsString('allowed\n');
    final lock = File('${temporary.path}/esdb.lock.json');
    await lock.writeAsString(
      jsonEncode({
        'esdbEvaluation': {
          'revision': 'test-revision',
          'requiredSha256': sha256
              .convert(await required.readAsBytes())
              .toString(),
          'allowedSha256': sha256
              .convert(await allowed.readAsBytes())
              .toString(),
        },
      }),
    );
    final exports = {'required': required.path, 'allowed': allowed.path};
    expect(await verifyEsdbExports(exports, path: lock.path), 'test-revision');
    await allowed.writeAsString('changed\n');
    await expectLater(
      verifyEsdbExports(exports, path: lock.path),
      throwsStateError,
    );
  });

  test(
    'strict vocabulary loading rejects duplicates and malformed entries',
    () async {
      final path = await candidate();
      await File('$path/words.txt').writeAsString('script\nscript\n');
      await expectLater(Vocabulary.load(path), throwsFormatException);
      await File('$path/words.txt').writeAsString('scr\uFFFDpt\n');
      await expectLater(Vocabulary.load(path), throwsFormatException);
    },
  );

  test(
    'generator is independent of dictionary order and returned object mutation',
    () async {
      final path = await candidate();
      final builder = AnagramLadderBuilder(
        wordsPath: '$path/words.txt',
        requiredWordsPath: '$path/requiredWords.txt',
      );
      final expected = (await builder.buildLadder('script', randomSeed: 12))!;
      final encoded = jsonEncode(expected.toJson());
      expected.words[0] = 'mutated';
      expect(
        jsonEncode(
          (await builder.buildLadder('script', randomSeed: 12))!.toJson(),
        ),
        encoded,
      );
      for (final name in ['words.txt', 'requiredWords.txt']) {
        final file = File('$path/$name');
        final lines = await file.readAsLines();
        await file.writeAsString('${lines.reversed.join('\n')}\n');
      }
      final reversed = AnagramLadderBuilder(
        wordsPath: '$path/words.txt',
        requiredWordsPath: '$path/requiredWords.txt',
      );
      expect(
        jsonEncode(
          (await reversed.buildLadder('script', randomSeed: 12))!.toJson(),
        ),
        encoded,
      );
    },
  );

  test(
    'CLI rejects unknown commands, missing options and existing output',
    () async {
      for (final args in [
        <String>[],
        ['not-a-command'],
        ['process_raw'],
        ['process_raw', '--output'],
        ['verify_sources', '--unexpected', 'value'],
        ['process_raw', '--output', 'one', '--output', 'two'],
      ]) {
        await expectLater(cli.run(args), throwsArgumentError);
      }
      await expectLater(
        cli.run(['snapshot_catalog', '--output', temporary.path]),
        throwsStateError,
      );
      final result = await Process.run('dart', [
        'run',
        'tools/main.dart',
        'not-a-command',
      ]);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('Unknown command'));
    },
  );
}
