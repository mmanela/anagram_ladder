import 'dart:io';

import 'package:anagram_ladder/anagram/anagramBuilder.dart';
import 'package:anagram_ladder/anagram/anagramLadderData.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:flutter_test/flutter_test.dart';

String sortedLetters(Iterable<String> letters) =>
    (letters.toList()..sort()).join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
