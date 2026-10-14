import 'dart:convert';

import 'package:anagram_ladder/models/levelState.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
