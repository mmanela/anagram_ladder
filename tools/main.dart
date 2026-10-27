import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:anagram_ladder/anagram/anagramBuilder.dart';

import 'ladder_pipeline.dart';
import 'vocabulary.dart';

const _usage = '''
Usage:
  dart run tools/main.dart process_raw --output <new-directory>
  dart run tools/main.dart build_ladders --vocabulary <directory> --output <new-directory>
  dart run tools/main.dart repair_ladders --vocabulary <directory> --output <new-directory>
  dart run tools/main.dart evaluate_esdb --required <size-35-export> --allowed <size-70-export> --output <new-directory>
  dart run tools/main.dart validate [--candidate <directory>]
  dart run tools/main.dart publish --candidate <directory>
  dart run tools/main.dart verify_sources
  dart run tools/main.dart snapshot_catalog --output <new-directory>
  dart run tools/main.dart snapshot_sources --output <new-directory>
All generation is staged. Publishing enforces the catalog lock and reviewed exceptions.
''';

Future<void> main(List<String> arguments) async {
  try {
    await run(arguments);
  } catch (error, stack) {
    stderr.writeln('Ladder tooling failed: $error');
    stderr.writeln(stack);
    exitCode = 1;
  }
}

Future<void> run(List<String> arguments) async {
  if (arguments.isEmpty) throw ArgumentError(_usage);
  final options = <String, String>{};
  for (var index = 1; index < arguments.length; index += 2) {
    if (!arguments[index].startsWith('--') ||
        index + 1 >= arguments.length ||
        options.containsKey(arguments[index]))
      throw ArgumentError(_usage);
    options[arguments[index]] = arguments[index + 1];
  }
  String required(String key) =>
      options[key] ?? (throw ArgumentError('Missing $key\n$_usage'));
  final command = arguments.first;
  final accepted = switch (command) {
    'process_raw' || 'snapshot_catalog' || 'snapshot_sources' => {'--output'},
    'build_ladders' || 'repair_ladders' => {'--output', '--vocabulary'},
    'evaluate_esdb' => {'--output', '--required', '--allowed'},
    'validate' || 'publish' => {'--candidate'},
    'verify_sources' => <String>{},
    _ => throw ArgumentError('Unknown command: $command\n$_usage'),
  };
  if (options.keys.any((key) => !accepted.contains(key)))
    throw ArgumentError(_usage);
  final encoder = const JsonEncoder.withIndent('  ');
  switch (command) {
    case 'process_raw':
    case 'evaluate_esdb':
      await verifySources();
      final exports = command == 'evaluate_esdb'
          ? {
              'required': required('--required'),
              'allowed': required('--allowed'),
            }
          : null;
      final sourceRevision = exports == null
          ? null
          : await verifyEsdbExports(exports);
      final build = await processVocabulary(scowlExports: exports);
      final previous = await Vocabulary.load(publishedDirectory, legacy: true);
      final catalog = await loadCatalog(publishedDirectory);
      // A source evaluation may remove published answers. Report that conflict
      // instead of quietly adding them back into the candidate dictionary.
      String? conflict;
      try {
        validateCatalog(catalog, build.vocabulary);
      } on StateError catch (error) {
        conflict = error.message.toString();
      }
      final conflicts = vocabularyConflicts(catalog, build.vocabulary);
      final changes = build.vocabulary.compare(previous);
      final exclusions =
          build.report['exclusions'] as List<Map<String, Object>>;
      final reasons = <String, int>{};
      for (final exclusion in exclusions) {
        final reason = exclusion['reason'] as String;
        reasons.update(reason, (count) => count + 1, ifAbsent: () => 1);
      }
      await writeCandidate(required('--output'), {
        ...build.vocabulary.files,
        ...catalogFiles(catalog),
        'report.json': encoder.convert({
          ...build.report,
          'vocabularyChanges': changes,
          'publishedCompatibilityError': conflict,
          'publishedConflicts': conflicts,
        }),
        'evaluation-summary.json': encoder.convert({
          'source': sourceRevision == null
              ? 'Pinned legacy sources'
              : 'ESDB $sourceRevision',
          'adoptedUpstreamRefresh': false,
          'previousVocabularyCounts': {
            'words': previous.words.length,
            'required': previous.required.length,
            'seeds': previous.seeds.length,
          },
          'catalogSnapshotHash': fingerprint(catalogSnapshot(catalog)),
          'counts': build.report['counts'],
          'changes': {
            for (final entry in changes.entries)
              entry.key: {
                'added': ((entry.value as Map)['added'] as List).length,
                'removed': ((entry.value as Map)['removed'] as List).length,
              },
          },
          'exclusionCounts': reasons,
          'conflictingRungs': conflicts.length,
          'conflictingPuzzles': conflicts
              .map((value) => '${value['world']}/${value['level']}')
              .toSet()
              .length,
          'protectedConflictingPuzzles': conflicts
              .where((value) => (value['level'] as int) <= 50)
              .map((value) => '${value['world']}/${value['level']}')
              .toSet()
              .length,
          'missingAcceptedAnswers': conflicts
              .expand(
                (value) => (value['missingAnswers'] as List).cast<String>(),
              )
              .toSet()
              .length,
          'hintPolicy': build.report['hintPolicy'],
          'conflictExamples': conflicts.take(10).toList(),
        }),
      });
      stdout.writeln(
        'Staged ${required('--output')}; published catalog unchanged.',
      );
      break;
    case 'build_ladders':
    case 'repair_ladders':
      final directory = required('--vocabulary');
      final vocabulary = await Vocabulary.load(directory);
      final builder = AnagramLadderBuilder(
        wordsPath: '$directory/words.txt',
        requiredWordsPath: '$directory/requiredWords.txt',
        seedsPath: '$directory/seedLetterSets.txt',
      );
      final catalog = command == 'build_ladders'
          ? await builder.buildLadders()
          : await builder.repairShortLadders();
      validateCatalog(catalog, vocabulary);
      final previous = await loadCatalog(publishedDirectory);
      await writeCandidate(required('--output'), {
        ...vocabulary.files,
        ...catalogFiles(catalog),
        'report.json': encoder.convert({
          ...await compareCatalogs(catalog, previous),
          'compatibilityChanges': await compatibilityChanges(catalog),
          'vocabularyHashes': {
            for (final entry in vocabulary.files.entries)
              entry.key: sha256.convert(utf8.encode(entry.value)).toString(),
          },
          'generator': {
            'version': 2,
            'seed': AnagramLadderBuilder.RandomSeedNumber,
          },
        }),
      });
      stdout.writeln(
        'Staged ${required('--output')}; review report.json before publication.',
      );
      break;
    case 'validate':
      final directory = options['--candidate'] ?? publishedDirectory;
      final catalog = await loadCatalog(directory);
      final vocabulary = await Vocabulary.load(directory);
      validateCatalog(catalog, vocabulary);
      final changes = await compatibilityChanges(catalog);
      if (changes.any((change) => change['approved'] != true)) {
        throw StateError(
          'Catalog compatibility violations: ${jsonEncode(changes)}',
        );
      }
      stdout.writeln('All 1,250 puzzles are valid and compatible.');
      break;
    case 'publish':
      await verifySources();
      await publishCandidate(required('--candidate'));
      stdout.writeln(
        'Published validated candidate. Only exact approved catalog changes are allowed.',
      );
      break;
    case 'verify_sources':
      await verifySources();
      stdout.writeln('All pinned local source checksums match.');
      break;
    case 'snapshot_catalog':
      await writeCandidate(required('--output'), {
        'catalog.lock.json': encoder.convert(
          catalogSnapshot(await loadCatalog(publishedDirectory)),
        ),
      });
      stdout.writeln(
        'Wrote catalog snapshot; never overwrite the committed compatibility baseline.',
      );
      break;
    case 'snapshot_sources':
      await writeCandidate(required('--output'), {
        'sources.lock.json': encoder.convert(await sourceSnapshot()),
      });
      stdout.writeln(
        'Wrote source snapshot; review metadata before committing.',
      );
      break;
  }
}
