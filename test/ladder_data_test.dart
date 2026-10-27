import 'dart:io';

import 'package:anagram_ladder/anagram/anagramBuilder.dart';
import 'package:anagram_ladder/anagram/anagramLadderData.dart';
import 'package:anagram_ladder/anagram/hintWordSelector.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:flutter_test/flutter_test.dart';

String sortedLetters(Iterable<String> letters) =>
    (letters.toList()..sort()).join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Expert 245 hints follow the repaired four-rung ladder', () async {
    final ladder = (await AnagramLadderData.getLadders(9))[244];
    final rungs = ladder.getBottomUp();
    expect(rungs.map((rung) => rung.letterCount), [5, 6, 7, 9]);
    expect(
      await Future.wait(
        rungs.map((rung) => HintWordSelector.shared.select(rung.words)),
      ),
      ['grain', 'raving', 'graving', 'averaging'],
    );
  });

  test('Normal 60 and Expert 141 hint lusts and retain both answers', () async {
    for (final (world, level) in [(6, 60), (9, 141)]) {
      final ladder = (await AnagramLadderData.getLadders(world))[level - 1];
      final rung = ladder.getBottomUp().singleWhere(
        (rung) => rung.words.contains('sluts'),
      );
      final originalWords = List<String>.of(rung.words);
      expect(rung.words, unorderedEquals(['sluts', 'lusts']));
      expect(await HintWordSelector.shared.select(rung.words), 'lusts');
      expect(rung.words, originalWords);
    }
  });

  test(
    'all bundled rungs have an eligible hint without changing answers',
    () async {
      final selector = HintWordSelector();
      var rungCount = 0;
      for (final world in GameState.worldIds) {
        final ladders = await AnagramLadderData.getLadders(world);
        for (var index = 0; index < ladders.length; index++) {
          for (final rung in ladders[index].getBottomUp()) {
            final before = List<String>.of(rung.words);
            final hint = await selector.select(rung.words);
            final reason = '$world/${index + 1}, ${rung.letterCount} letters';
            expect(rung.words, contains(hint), reason: reason);
            expect(
              HintWordSelector.excludedHintWords,
              isNot(contains(hint)),
              reason: reason,
            );
            expect(rung.words, before, reason: reason);
            rungCount++;
          }
        }
      }
      expect(rungCount, 4500);
    },
  );

  test(
    'approved repairs retain shape and accept replacement progress',
    () async {
      for (final entry in LevelState.catalogRepairs.entries) {
        final (world, level) = entry.key;
        final ladder = (await AnagramLadderData.getLadders(world))[level - 1];
        final rungs = ladder.getBottomUp();
        expect(
          rungs.map((rung) => rung.letterCount),
          entry.value.before.map((word) => word.length),
        );
        for (var index = 0; index < rungs.length; index++) {
          expect(rungs[index].words, contains(entry.value.after[index]));
          expect(
            rungs[index].words.toSet().intersection(
              HintWordSelector.excludedHintWords,
            ),
            isEmpty,
          );
        }
      }
    },
  );

  test('each difficulty has 250 distinct, solvable ladders', () async {
    final allowedWords = (await File(
      AnagramLadderBuilder.ProcessWordFilePath,
    ).readAsLines()).toSet();
    final requiredWords = (await File(
      AnagramLadderBuilder.RequiredWordFilePath,
    ).readAsLines()).toSet();

    for (final world in GameState.worldIds) {
      final ladders = await AnagramLadderData.getLadders(world);
      expect(ladders, hasLength(250));
      final playable = ladders;
      expect(
        playable.map((ladder) => sortedLetters(ladder.letters)).toSet(),
        hasLength(250),
      );
      for (var index = 0; index < playable.length; index++) {
        final ladder = playable[index];
        final reason = 'Difficulty $world, level ${index + 1}';
        expect(ladder.letterCount, world, reason: reason);
        final rungs = ladder.getBottomUp();
        expect(rungs.length, greaterThanOrEqualTo(3), reason: reason);
        for (final rung in rungs) {
          expect(
            rung.letters,
            everyElement(matches(r'^[a-z]$')),
            reason: reason,
          );
          expect(
            rung.lettersToAdd,
            everyElement(matches(r'^[a-z]$')),
            reason: reason,
          );
          expect(rung.words, isNotEmpty, reason: reason);
          expect(
            rung.words.toSet(),
            hasLength(rung.words.length),
            reason: reason,
          );
          expect(
            rung.words.any(requiredWords.contains),
            isTrue,
            reason: reason,
          );
          expect(rung.levelWordCount, rung.words.length, reason: reason);
          for (final word in rung.words) {
            expect(word, matches(r'^[a-z]+$'), reason: reason);
            expect(allowedWords, contains(word), reason: reason);
            expect(
              sortedLetters(word.split('')),
              sortedLetters(rung.letters),
              reason: reason,
            );
          }
          final child = rung.childLevel;
          expect(rung.rung, child == null ? 0 : child.rung + 1, reason: reason);
          expect(
            rung.totalWordCount,
            rung.words.length + (child?.totalWordCount ?? 0),
            reason: reason,
          );
          if (child == null) {
            expect(rung.lettersToAdd, isEmpty, reason: reason);
          }
          if (child != null) {
            expect(
              rung.letterCount,
              greaterThan(child.letterCount),
              reason: reason,
            );
            expect(
              sortedLetters([...child.letters, ...rung.lettersToAdd]),
              sortedLetters(rung.letters),
              reason: reason,
            );
          }
        }
      }
    }
  });
}
