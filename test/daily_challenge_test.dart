import 'dart:convert';

import 'package:anagram_ladder/models/dailyChallenge.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_state_test.dart' show completedLevel;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameStore store;
  late GameState game;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 14, 12);
    store = GameStore();
    game = GameState(store, now: () => now);
    await game.initialize();
  });

  tearDown(() {
    game.dispose();
    store.dispose();
  });

  test('the same calendar date selects the same free Normal puzzle', () async {
    final start = DailyChallenge(DateTime(2026, 10, 14));
    final end = DailyChallenge(DateTime(2026, 10, 14, 23, 59));
    expect(start.dateKey, '2026-10-14');
    expect(start.level, end.level);
    expect(DailyChallenge.world, 6);
    final levels = <int>{};
    for (var day = 0; day < DailyChallenge.puzzleCount; day++) {
      final challenge = DailyChallenge(DateTime(2026, 10, 14 + day));
      expect(challenge.level, inInclusiveRange(1, 50));
      levels.add(challenge.level);
    }
    expect(levels, hasLength(50));
    expect(
      DailyChallenge(DateTime(2026, 3, 9)).dayNumber -
          DailyChallenge(DateTime(2026, 3, 8)).dayNumber,
      1,
    );
    expect(DailyChallenge.tryParse('2026-02-30'), isNull);
    expect(DailyChallenge.tryParse('2026-2-3'), isNull);
    expect(DailyChallenge.tryParse('2028-02-29')!.date.day, 29);
  });

  test('daily saves and completions do not affect regular progress', () async {
    final day = game.today;
    final regular = await completedLevel(game, 6, day.level);
    regular.currentRung = 1;
    await game.persistLevelState(regular);
    final before = jsonEncode(game.getLevelState(6, day.level).toJson());
    final resume = game.resumeLevel!;
    final count = game.getWorldCompletionInfo(6).completedCount;

    final daily = await completedLevel(game, 6, day.level);
    await game.persistDailyState(day, daily);
    expect(game.isDailyCompleted(day), isTrue);
    expect(game.getDailyState(day).isWon, isTrue);
    expect(jsonEncode(game.getLevelState(6, day.level).toJson()), before);
    expect(game.resumeLevel!.world, resume.world);
    expect(game.resumeLevel!.level, resume.level);
    expect(game.getWorldCompletionInfo(6).completedCount, count);
    final reopened = GameState(store, now: () => now);
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.isDailyCompleted(day), isTrue);
    expect(reopened.getDailyState(day).levelLetters, daily.levelLetters);
  });

  test(
    'replays keep the completion calendar and dates have separate saves',
    () async {
      final day = game.today;
      final progress = await completedLevel(game, 6, day.level);
      await game.persistDailyState(day, progress);
      progress.currentRung = 0;
      await game.persistDailyState(day, progress);
      expect(game.isDailyCompleted(day), isTrue);
      expect(game.getDailyState(day).currentRung, 0);
      now = DateTime(2026, 10, 15);
      game.refreshDaily();
      expect(game.today.dateKey, '2026-10-15');
      expect(game.getDailyState(game.today).isEmpty, isTrue);
      expect(game.isDailyCompleted(game.today), isFalse);
      expect(game.isDailyCompleted(day), isTrue);
      expect(game.getDailyState(day).currentRung, 0);
    },
  );

  test(
    'resuming after midnight refreshes the date, not an open puzzle save',
    () async {
      final day = game.today;
      final progress = await completedLevel(game, 6, day.level);
      progress.currentRung = 1;
      await game.persistDailyState(day, progress);
      now = DateTime(2026, 10, 15, 8);
      game.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(game.today.dateKey, '2026-10-15');
      progress.currentRung = progress.rungCount;
      await game.persistDailyState(day, progress);
      expect(game.isDailyCompleted(day), isTrue);
      expect(game.isDailyCompleted(game.today), isFalse);
    },
  );

  testWidgets('the daily clock rolls over while the app stays open', (
    tester,
  ) async {
    now = DateTime(2026, 10, 14, 23, 59, 59);
    final ticking = GameState(store, now: () => now);
    try {
      ticking.refreshDaily();
      now = DateTime(2026, 10, 15);
      await tester.pump(const Duration(seconds: 1));
      expect(ticking.today.dateKey, '2026-10-15');
    } finally {
      ticking.dispose();
    }
  });

  test(
    'daily sharing contains the date and rung shapes, never answers',
    () async {
      final progress = await completedLevel(game, 6, game.today.level);
      final text = game.today.shareText(
        progress.levelLetters.map((row) => row.length).toList(),
      );
      expect(text, contains('Daily 2026-10-14'));
      expect(text, contains('Normal | 3/3 rungs solved'));
      expect(text, contains('\u{1F7E9}' * 6));
      for (final row in progress.levelLetters) {
        expect(text, isNot(contains(row.join())));
      }
    },
  );

  test(
    'reset clears daily history but keeps feedback and learned controls',
    () async {
      final day = game.today;
      await game.persistDailyState(
        day,
        await completedLevel(game, 6, day.level),
      );
      await game.setHapticsEnabled(false);
      await game.markControlsLearned();
      await game.reset();
      expect(game.getDailyState(day).isEmpty, isTrue);
      expect(game.isDailyCompleted(day), isFalse);
      expect(game.hapticsEnabled, isFalse);
      expect(game.controlsLearned, isTrue);
    },
  );

  test('invalid daily saves are rejected instead of silently reset', () async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'daily_v1_progress_${game.today.dateKey}';
    await prefs.setString(key, '{"currentRung":99}');
    expect(() => game.getDailyState(game.today), throwsFormatException);
    expect(prefs.getString(key), '{"currentRung":99}');
    final progress = await completedLevel(game, 6, game.today.level);
    final mismatched = LevelState(
      6,
      game.today.level == 50 ? 1 : game.today.level + 1,
      6,
      3,
      3,
      progress.levelLetters,
    );
    await expectLater(
      game.persistDailyState(game.today, mismatched),
      throwsArgumentError,
    );
  });
}
