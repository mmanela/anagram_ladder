import 'dart:convert';
import 'dart:io';

import 'package:anagram_ladder/anagram/anagramBuilder.dart';
import 'package:anagram_ladder/anagram/anagramLadderData.dart';
import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ladder_data_test.dart' show sortedLetters;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ranking keeps word variety before a stable letter-set tiebreak', () {
    final fewerTopWords = LadderLevel(
      'aerst'.split(''),
      1,
      LadderLevel.bottom('aers'.split(''), 3, ['ares', 'ears', 'eras']),
      ['stare'],
    );
    final moreTopWords = LadderLevel(
      'aerst'.split(''),
      2,
      LadderLevel.bottom('aers'.split(''), 2, ['ares', 'ears']),
      ['stare', 'rates'],
    );
    expect(moreTopWords.compareTo(fewerTopWords), lessThan(0));
    final first = LadderLevel.bottom('iprs'.split(''), 1, ['rips']);
    final second = LadderLevel.bottom('irst'.split(''), 1, ['stir']);
    expect(first.compareTo(second), lessThan(0));
    expect(second.compareTo(first), greaterThan(0));
  });

  test(
    'selection is repeatable regardless of call order and random seeds',
    () async {
      final shared = AnagramLadderBuilder();
      for (final world in GameState.worldIds) {
        final ladders = await AnagramLadderData.getLadders(world);
        for (final index in [0, 1, 49, 97, 249]) {
          final seed = ladders[index].letters.join();
          final first = await shared.buildLadder(seed, randomSeed: 42);
          await shared.buildLadder(seed, randomSeed: 777);
          await shared.buildLadder(ladders[(index + 1) % 250].letters.join());
          final repeated = await shared.buildLadder(seed, randomSeed: 42);
          final isolated = await AnagramLadderBuilder().buildLadder(
            seed,
            randomSeed: 42,
          );
          expect(jsonEncode(repeated!.toJson()), jsonEncode(first!.toJson()));
          expect(jsonEncode(isolated!.toJson()), jsonEncode(first.toJson()));
          expect(
            first.getBottom().letterCount,
            greaterThanOrEqualTo(
              AnagramLadderBuilder.MinimumWordLengthMap[world]!,
            ),
          );
        }
      }
    },
  );

  test(
    'invalid seed characters fail rather than generating malformed puzzles',
    () async {
      final builder = AnagramLadderBuilder();
      for (final seed in [
        'ciprs\uFFFD',
        'script!',
        'SCRIPT',
        'short',
        'abcdefghijk',
      ]) {
        await expectLater(builder.buildLadder(seed), throwsArgumentError);
      }
    },
  );

  test(
    'generation finds the longest valid path for every bundled seed',
    () async {
      final required = (await File(
        AnagramLadderBuilder.RequiredWordFilePath,
      ).readAsLines()).map((word) => sortedLetters(word.split(''))).toSet();
      final cache = <(String, int), int>{};

      int longestPath(String letters, int minimum) {
        final key = (letters, minimum);
        final cached = cache[key];
        if (cached != null) return cached;
        var longestChild = 0;
        if (letters.length > minimum) {
          final subsets = {
            for (var index = 0; index < letters.length; index++)
              letters.substring(0, index) + letters.substring(index + 1),
          };
          for (final subset in subsets) {
            final length = longestPath(subset, minimum);
            if (length > longestChild) longestChild = length;
          }
        }
        return cache[key] = longestChild + (required.contains(letters) ? 1 : 0);
      }

      final builder = AnagramLadderBuilder();
      for (final world in GameState.worldIds) {
        final ladders = await AnagramLadderData.getLadders(world);
        final minimum = AnagramLadderBuilder.MinimumWordLengthMap[world]!;
        for (var index = 0; index < ladders.length; index++) {
          final seed = ladders[index].letters.join();
          final generated = await builder.buildLadder(seed, randomSeed: index);
          final reason = 'Difficulty $world, level ${index + 1}, seed $seed';
          expect(generated, isNotNull, reason: reason);
          expect(generated!.letterCount, world, reason: reason);
          expect(
            generated.getBottomUp().length,
            longestPath(seed, minimum),
            reason: reason,
          );
        }
      }
    },
  );
}
