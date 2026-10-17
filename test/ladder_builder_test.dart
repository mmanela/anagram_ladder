import 'dart:io';

import 'package:anagram_ladder/anagram/anagramBuilder.dart';
import 'package:anagram_ladder/anagram/anagramLadderData.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ladder_data_test.dart' show sortedLetters;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
