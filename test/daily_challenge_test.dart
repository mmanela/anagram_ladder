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

  test(
    'daily selection is stable and visits every difficulty and puzzle',
    () async {
      final start = DailyChallenge(DateTime(2026, 10, 14));
      final end = DailyChallenge(DateTime(2026, 10, 14, 23, 59));
      expect(start.dateKey, '2026-10-14');
      expect(start.level, end.level);
      expect(start.world, end.world);
      final puzzles = <(int, int)>{};
      final counts = {for (final world in GameState.worldIds) world: 0};
      for (var day = 0; day < DailyChallenge.puzzleCount; day++) {
        final challenge = DailyChallenge(DateTime(2026, 10, 14 + day));
        expect(challenge.level, inInclusiveRange(1, 250));
        expect(GameState.worldIds, contains(challenge.world));
        puzzles.add((challenge.world, challenge.level));
        counts.update(challenge.world, (count) => count + 1);
        final ladder = await game.getDailyLadder(challenge);
        expect(ladder.letterCount, challenge.world);
        expect(challenge.difficulty, GameState.worldLabels[challenge.world]);
      }
      expect(puzzles, hasLength(1250));
      expect(counts.values, everyElement(250));
      expect(game.maxLevelsPerWorld, 50);
      for (final world in GameState.worldIds) {
        expect(game.getWorldLevelCount(world), 50);
      }
      final repeated = DailyChallenge(DateTime(2026, 10, 14 + 1250));
      expect((repeated.world, repeated.level), (start.world, start.level));
      expect(
        DailyChallenge(DateTime(2026, 3, 9)).dayNumber -
            DailyChallenge(DateTime(2026, 3, 8)).dayNumber,
        1,
      );
      expect(DailyChallenge.tryParse('2026-02-30'), isNull);
      expect(DailyChallenge.tryParse('2026-2-3'), isNull);
      expect(DailyChallenge.tryParse('2028-02-29')!.date.day, 29);
    },
  );

  test('daily saves and completions do not affect regular progress', () async {
    final day = game.today;
    final regular = await completedLevel(game, day.world, 1);
    regular.currentRung = 1;
    await game.persistLevelState(regular);
    final before = jsonEncode(game.getLevelState(day.world, 1).toJson());
    final resume = game.resumeLevel!;
    final count = game.getWorldCompletionInfo(day.world).completedCount;

    final daily = await completedLevel(game, day.world, day.level);
    await game.persistDailyState(day, daily);
    expect(game.isDailyCompleted(day), isTrue);
    expect(game.getDailyState(day).isWon, isTrue);
    expect(jsonEncode(game.getLevelState(day.world, 1).toJson()), before);
    expect(game.resumeLevel!.world, resume.world);
    expect(game.resumeLevel!.level, resume.level);
    expect(game.getWorldCompletionInfo(day.world).completedCount, count);
    final reopened = GameState(store, now: () => now);
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.isDailyCompleted(day), isTrue);
    expect(reopened.getDailyState(day).levelLetters, daily.levelLetters);
  });

  test('the shuffled schedule stays fixed across releases', () {
    expect(
      [
        for (var offset = 0; offset < 7; offset++)
          (
            DailyChallenge(DateTime(2026, 10, 14 + offset)).world,
            DailyChallenge(DateTime(2026, 10, 14 + offset)).level,
          ),
      ],
      [(9, 84), (8, 235), (9, 245), (6, 122), (8, 231), (7, 212), (6, 178)],
    );
    expect(
      [
        for (var offset = 0; offset < 7; offset++)
          (
            DailyChallenge.previous(DateTime(2026, 10, 14 + offset)).world,
            DailyChallenge.previous(DateTime(2026, 10, 14 + offset)).level,
          ),
      ],
      [(10, 34), (6, 32), (10, 50), (10, 32), (7, 10), (8, 38), (7, 23)],
    );
  });

  test(
    'Normal 98 migration does not parse unrelated daily saves at startup',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final key = 'daily_v3_progress_${game.today.dateKey}';
      expect((game.today.world, game.today.level), isNot((6, 98)));
      await preferences.setString(key, 'invalid-json');
      await game.initialize(force: true);
      expect(preferences.getString(key), 'invalid-json');
      expect(() => game.getDailyState(game.today), throwsFormatException);
    },
  );

  test(
    'Normal 98 daily repair persists without changing dated selection',
    () async {
      final day = [
        for (var offset = 0; offset < DailyChallenge.puzzleCount; offset++)
          DailyChallenge(DateTime(2026, 1, 1 + offset)),
      ].firstWhere((day) => day.world == 6 && day.level == 98);
      final preferences = await SharedPreferences.getInstance();
      for (final currentRung in [2, 3]) {
        final old = LevelState(6, 98, 6, currentRung, 3, [
          'rips'.split(''),
          'crisp'.split(''),
          'pr\uFFFDcis'.split(''),
        ]);
        final key = 'daily_v3_progress_${day.dateKey}';
        await preferences.setString(key, jsonEncode(old.toJson()));
        await preferences.setBool(
          'daily_v3_completed_${day.dateKey}',
          currentRung == 3,
        );
        await game.initialize(force: true);
        final repaired = game.getDailyState(day);
        expect(repaired.currentRung, currentRung);
        expect(
          repaired.levelLetters.last.join(),
          currentRung == 3 ? 'script' : 'prtcis',
        );
        expect(game.isDailyCompleted(day), currentRung == 3);
        expect(preferences.getString(key), isNot(contains('\uFFFD')));
        expect((await game.getDailyLadder(day)).words, ['script']);
        expect(game.getLevelState(6, 98).isEmpty, isTrue);
      }
    },
  );

  test('Expert 245 daily repair retains selection and completion', () async {
    final day = [
      for (var offset = 0; offset < DailyChallenge.puzzleCount; offset++)
        DailyChallenge(DateTime(2026, 1, 1 + offset)),
    ].firstWhere((day) => day.world == 9 && day.level == 245);
    final preferences = await SharedPreferences.getInstance();
    final key = 'daily_v3_progress_${day.dateKey}';
    for (var currentRung = 0; currentRung <= 4; currentRung++) {
      final old = LevelState(9, 245, 9, currentRung, 4, [
        'again'.split(''),
        'vagina'.split(''),
        'vaginae'.split(''),
        'averaging'.split(''),
      ]);
      await preferences.setString(key, jsonEncode(old.toJson()));
      await preferences.setBool(
        'daily_v3_completed_${day.dateKey}',
        currentRung == 4,
      );
      await game.initialize(force: true);
      final repaired = game.getDailyState(day);
      expect(repaired.currentRung, currentRung);
      expect(repaired.levelLetters.last.join(), 'averaging');
      expect(game.isDailyCompleted(day), currentRung == 4);
      expect(preferences.getString(key), jsonEncode(repaired.toJson()));
      expect(
        (await game.getDailyLadder(day))
            .getBottomUp()
            .map((rung) => rung.words),
        [
          ['grain'],
          ['raving'],
          ['graving'],
          ['averaging'],
        ],
      );
      expect(game.getLevelState(9, 245).isEmpty, isTrue);
      await game.initialize(force: true);
      expect(game.getDailyState(day).toJson(), repaired.toJson());
    }
  });

  test('catalog repairs persist v1, v2 and v3 daily selections', () async {
    final preferences = await SharedPreferences.getInstance();
    for (final version in [1, 2, 3]) {
      for (final entry in LevelState.catalogRepairs.entries) {
        final (world, level) = entry.key;
        if (version < 3 && (level > 50 || (version == 1 && world != 6))) {
          continue;
        }
        final days = [
          for (var offset = 0; offset < DailyChallenge.puzzleCount; offset++)
            switch (version) {
              1 => DailyChallenge.legacy(DateTime(2026, 1, 1 + offset)),
              2 => DailyChallenge.previous(DateTime(2026, 1, 1 + offset)),
              _ => DailyChallenge(DateTime(2026, 1, 1 + offset)),
            },
        ];
        final day = days.firstWhere(
          (day) =>
              day.world == world &&
              day.level == level &&
              (version == 1 ||
                  !preferences.containsKey(
                    'daily_v1_progress_${day.dateKey}',
                  )) &&
              (version != 3 ||
                  !preferences.containsKey('daily_v2_progress_${day.dateKey}')),
        );
        final words = entry.value.before;
        final key = 'daily_v${version}_progress_${day.dateKey}';
        final completedKey = 'daily_v${version}_completed_${day.dateKey}';
        for (var currentRung = 0; currentRung <= words.length; currentRung++) {
          final old = LevelState(
            world,
            level,
            world,
            currentRung,
            words.length,
            words.map((word) => word.split('')).toList(),
          );
          await preferences.setString(key, jsonEncode(old.toJson()));
          await preferences.setBool(completedKey, currentRung == words.length);
          final expected = LevelState.fromJson(old.toJson());
          await game.initialize(force: true);
          expect(game.getDailyState(day).toJson(), expected.toJson());
          expect(preferences.getString(key), jsonEncode(expected.toJson()));
          expect(game.isDailyCompleted(day), currentRung == words.length);
          expect(
            (
              game.dailyForDate(day.date).world,
              game.dailyForDate(day.date).level,
            ),
            (world, level),
          );
          expect(game.getLevelState(world, level).isEmpty, isTrue);
        }
        await preferences.remove(key);
        await preferences.remove(completedKey);
      }
    }
  });

  test('started v2 dailies keep their original puzzle and progress', () async {
    final old = DailyChallenge.previous(now);
    final progress = await completedLevel(game, old.world, old.level);
    progress.currentRung = 1;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'daily_v2_progress_${old.dateKey}',
      jsonEncode(progress.toJson()),
    );
    expect(game.today.isPrevious, isTrue);
    expect((game.today.world, game.today.level), (old.world, old.level));
    expect(game.getDailyState(game.today).currentRung, 1);
    progress.currentRung = progress.rungCount;
    await game.persistDailyState(game.today, progress);
    expect(game.isDailyCompleted(game.today), isTrue);
    expect(
      preferences.containsKey('daily_v3_progress_${old.dateKey}'),
      isFalse,
    );
  });

  test(
    'existing Normal daily saves keep their puzzle and completion',
    () async {
      final old = DailyChallenge.legacy(now);
      final progress = await completedLevel(game, old.world, old.level);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'daily_v1_progress_${old.dateKey}',
        jsonEncode(progress.toJson()),
      );
      await prefs.setBool('daily_v1_completed_${old.dateKey}', true);
      expect(game.today.isLegacy, isTrue);
      expect(game.today.world, 6);
      expect(game.today.level, old.level);
      expect(
        game.getDailyState(DailyChallenge(now)).levelLetters,
        progress.levelLetters,
      );
      expect(game.isDailyCompleted(DailyChallenge(now)), isTrue);
      progress.currentRung = 0;
      await game.persistDailyState(game.today, progress);
      expect(game.isDailyCompleted(game.today), isTrue);
      expect(prefs.containsKey('daily_v2_progress_${old.dateKey}'), isFalse);
      final reopened = GameState(store, now: () => now);
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.today.world, 6);
      expect(reopened.getDailyState(reopened.today).currentRung, 0);
      await game.reset();
      expect(prefs.getKeys().where((key) => key.startsWith('daily_')), isEmpty);
      expect(game.today.isLegacy, isFalse);
    },
  );

  test(
    'replays keep the completion calendar and dates have separate saves',
    () async {
      final day = game.today;
      final progress = await completedLevel(game, day.world, day.level);
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
      final progress = await completedLevel(game, day.world, day.level);
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

  test('daily sharing contains the date and rung shapes, never answers', () async {
    final day = game.today;
    final progress = await completedLevel(game, day.world, day.level);
    final text = day.shareText(
      progress.levelLetters.map((row) => row.length).toList(),
    );
    expect(text, contains('Daily 2026-10-14'));
    expect(
      text,
      contains(
        '${day.difficulty} | ${progress.rungCount}/${progress.rungCount} rungs solved',
      ),
    );
    expect(text, contains('\u{1F7E9}' * day.world));
    for (final row in progress.levelLetters) {
      expect(text, isNot(contains(row.join())));
    }
  });

  test(
    'reset clears daily history but keeps feedback and learned controls',
    () async {
      final day = game.today;
      await game.persistDailyState(
        day,
        await completedLevel(game, day.world, day.level),
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
    final key = 'daily_v2_progress_${game.today.dateKey}';
    await prefs.setString(key, '{"currentRung":99}');
    expect(() => game.getDailyState(game.today), throwsFormatException);
    expect(prefs.getString(key), '{"currentRung":99}');
    final progress = await completedLevel(
      game,
      game.today.world,
      game.today.level,
    );
    final mismatched = LevelState(
      game.today.world,
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
