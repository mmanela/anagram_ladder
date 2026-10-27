import 'dart:convert';

import 'package:anagram_ladder/models/levelState.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'catalog repairs preserve progress, completion and blank future rows',
    () {
      for (final entry in LevelState.catalogRepairs.entries) {
        final (world, level) = entry.key;
        final before = entry.value.before;
        final after = entry.value.after;
        for (var currentRung = 0; currentRung <= before.length; currentRung++) {
          for (final populatedFuture in [false, true]) {
            final old = LevelState(
              world,
              level,
              currentRung == 0 ? 0 : before[currentRung - 1].length,
              currentRung,
              before.length,
              [
                for (var index = 0; index < before.length; index++)
                  index <= currentRung || populatedFuture
                      ? before[index].split('').reversed.toList()
                      : List.filled(before[index].length, ''),
              ],
            );
            final originalRows = old.levelLetters.map(List<String>.of).toList();
            final repaired = LevelState.fromJson(old.toJson());
            final reason =
                '$world/$level at $currentRung, future=$populatedFuture';
            expect(repaired.currentRung, currentRung, reason: reason);
            expect(repaired.maxWordLength, old.maxWordLength, reason: reason);
            expect(
              repaired.isWon,
              currentRung == before.length,
              reason: reason,
            );
            for (var index = 0; index < before.length; index++) {
              final changed =
                  (before[index].split('')..sort()).join() !=
                  (after[index].split('')..sort()).join();
              final occupied = originalRows[index].any(
                (letter) => letter.isNotEmpty,
              );
              final expected = !changed || !occupied
                  ? originalRows[index]
                  : index < currentRung
                  ? after[index].split('')
                  : (after[index].split('')..sort());
              expect(repaired.levelLetters[index], expected, reason: reason);
            }
            expect(repaired.repairPublishedLadder(), isFalse, reason: reason);
            expect(
              LevelState.fromJson(repaired.toJson()).toJson(),
              repaired.toJson(),
              reason: reason,
            );
          }
        }
      }
    },
  );

  test('catalog repairs do not change unrelated or already replaced rows', () {
    for (final entry in LevelState.catalogRepairs.entries) {
      final (world, level) = entry.key;
      final words = entry.value.after;
      for (final savedLevel in [level, 1]) {
        final state = LevelState(
          world,
          savedLevel,
          0,
          0,
          words.length,
          words.map((word) => word.split('')).toList(),
        );
        final before = jsonEncode(state.toJson());
        expect(state.repairPublishedLadder(), isFalse);
        expect(jsonEncode(state.toJson()), before);
      }
    }
  });

  test('Expert 245 repair retains blank future rows and is idempotent', () {
    for (var currentRung = 0; currentRung <= 4; currentRung++) {
      const oldWords = ['again', 'vagina', 'vaginae', 'averaging'];
      const newWords = ['grain', 'raving', 'graving', 'averaging'];
      final old = LevelState(
        9,
        245,
        currentRung == 0 ? 0 : oldWords[currentRung - 1].length,
        currentRung,
        4,
        [
          for (var index = 0; index < oldWords.length; index++)
            index <= currentRung
                ? oldWords[index].split('')
                : List.filled(oldWords[index].length, ''),
        ],
      );
      final repaired = LevelState.fromJson(old.toJson());
      expect(repaired.currentRung, currentRung);
      expect(repaired.maxWordLength, old.maxWordLength);
      expect(repaired.isWon, currentRung == 4);
      for (var index = 0; index < 4; index++) {
        if (index < currentRung) {
          expect(repaired.levelLetters[index].join(), newWords[index]);
        } else if (index == currentRung && index < 3) {
          expect(
            repaired.levelLetters[index],
            newWords[index].split('')..sort(),
          );
        } else {
          expect(repaired.levelLetters[index], old.levelLetters[index]);
        }
      }
      expect(repaired.repairExpert245(), isFalse);
      expect(
        LevelState.fromJson(repaired.toJson()).toJson(),
        repaired.toJson(),
      );
    }
  });

  test(
    'Expert repair does not alter a different level or new arrangements',
    () {
      for (final (level, bottom) in [(244, 'again'), (245, 'grain')]) {
        final state = LevelState(9, level, 0, 0, 4, [
          bottom.split(''),
          List.filled(6, ''),
          List.filled(7, ''),
          List.filled(9, ''),
        ]);
        final before = jsonEncode(state.toJson());
        expect(state.repairExpert245(), isFalse);
        expect(jsonEncode(state.toJson()), before);
      }
    },
  );

  test('existing v5 saved progress still loads and round-trips', () async {
    final letters = [
      ['t', 'e', 'a', 'm'],
      ['t', 'e', 'a', 'm', 's'],
      ['', '', '', '', '', ''],
    ];
    SharedPreferences.setMockInitialValues({
      'v5_6_1_world': 6,
      'v5_6_1_level': 1,
      'v5_6_1_maxWordLength': 4,
      'v5_6_1_currentRung': 1,
      'v5_6_1_rungCount': 3,
      'v5_6_1_levelLetters': jsonEncode(letters),
    });
    final preferences = await SharedPreferences.getInstance();
    final state = LevelState.fromSharedPreferences(6, 1, preferences);

    expect(state.isEmpty, isFalse);
    expect(state.currentRung, 1);
    expect(state.percentComplete, 1 / 3);
    expect(state.levelLetters, letters);

    state.currentRung = 3;
    await state.save(preferences);
    final reloaded = LevelState.fromSharedPreferences(6, 1, preferences);
    expect(reloaded.isWon, isTrue);
    expect(reloaded.levelLetters, letters);
    expect(preferences.getInt('v5_6_1_currentRung'), 3);
    expect(LevelState.fromSharedPreferences(6, 2, preferences).isEmpty, isTrue);
  });
}
