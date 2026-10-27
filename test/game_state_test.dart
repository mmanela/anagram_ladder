import 'dart:async';
import 'dart:convert';

import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/anagram/anagramLadderData.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestUnlockStore extends GameStore {
  bool _unlocked = false;

  @override
  bool get hasUnlocked51To100 => _unlocked;

  void unlockLevels() {
    _unlocked = true;
    notifyListeners();
  }
}

Future<LevelState> completedLevel(GameState state, int world, int level) async {
  final ladder = level <= state.getWorldLevelCount(world)
      ? await state.getLevelOrLoad(world, level)
      : (await AnagramLadderData.getLadders(world))[level - 1];
  final rungs = ladder.getBottomUp();
  return LevelState(
    world,
    level,
    ladder.letterCount,
    rungs.length,
    rungs.length,
    rungs.map((rung) => rung.words.first.split('')).toList(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestUnlockStore store;
  late GameState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = TestUnlockStore();
    state = GameState(store);
    await state.initialize();
  });

  tearDown(() {
    state.dispose();
    store.dispose();
  });

  test('new games load all five difficulties with 50 free levels each', () {
    expect(state.isLoaded, isTrue);
    expect(GameState.worldIds, [6, 7, 8, 9, 10]);
    expect(state.maxLevelsPerWorld, 50);
    for (final world in GameState.worldIds) {
      expect(state.getWorldLevelCount(world), 50);
      final completion = state.getWorldCompletionInfo(world);
      expect(completion.levelCount, 50);
      expect(completion.completedCount, 0);
      expect(completion.percent, 0);
      expect(state.isWorldDone(world), isFalse);
    }
    expect(state.isGameDone(), isFalse);
  });

  test(
    'Normal 98 repair preserves lower rungs, progress and completion',
    () async {
      final preferences = await SharedPreferences.getInstance();
      for (final currentRung in [0, 1, 2, 3]) {
        await LevelState(6, 98, 6, currentRung, 3, [
          'rips'.split(''),
          'crisp'.split(''),
          'pr\uFFFDcis'.split(''),
        ]).save(preferences);
        await state.initialize(force: true);
        final repaired = state.getLevelState(6, 98);
        expect(repaired.currentRung, currentRung);
        expect(repaired.isWon, currentRung == 3);
        expect(repaired.levelLetters.take(2), [
          'rips'.split(''),
          'crisp'.split(''),
        ]);
        expect(
          repaired.levelLetters.last.join(),
          currentRung == 3 ? 'script' : 'prtcis',
        );
        expect(
          preferences.getString('v5_6_98_levelLetters'),
          isNot(contains('\uFFFD')),
        );
        await state.initialize(force: true);
        expect(state.getLevelState(6, 98).toJson(), repaired.toJson());
      }
    },
  );

  test('Expert 245 repair persists regular progress and completion', () async {
    final preferences = await SharedPreferences.getInstance();
    for (var currentRung = 0; currentRung <= 4; currentRung++) {
      await LevelState(9, 245, 9, currentRung, 4, [
        'again'.split(''),
        'vagina'.split(''),
        'vaginae'.split(''),
        'averaging'.split(''),
      ]).save(preferences);
      await state.initialize(force: true);
      final repaired = state.getLevelState(9, 245);
      expect(repaired.currentRung, currentRung);
      expect(repaired.isWon, currentRung == 4);
      expect(repaired.levelLetters.last.join(), 'averaging');
      expect(
        preferences.getString('v5_9_245_levelLetters'),
        isNot(contains('["v","a","g","i","n","a"]')),
      );
      expect(
        preferences.getString('v5_9_245_levelLetters'),
        jsonEncode(repaired.levelLetters),
      );
      await state.initialize(force: true);
      expect(state.getLevelState(9, 245).toJson(), repaired.toJson());
    }
  });

  test('all approved catalog repairs persist regular saved progress', () async {
    final preferences = await SharedPreferences.getInstance();
    for (final entry in LevelState.catalogRepairs.entries) {
      final (world, level) = entry.key;
      final words = entry.value.before;
      for (var currentRung = 0; currentRung <= words.length; currentRung++) {
        final old = LevelState(
          world,
          level,
          world,
          currentRung,
          words.length,
          words.map((word) => word.split('')).toList(),
        );
        await old.save(preferences);
        final expected = LevelState.fromJson(old.toJson());
        await state.initialize(force: true);
        final repaired = state.getLevelState(world, level);
        expect(repaired.toJson(), expected.toJson());
        expect(
          preferences.getString('v5_${world}_${level}_levelLetters'),
          jsonEncode(repaired.levelLetters),
        );
        await state.initialize(force: true);
        expect(state.getLevelState(world, level).toJson(), expected.toJson());
      }
    }
  });

  test(
    'disposing during game loading does not notify disposed listeners',
    () async {
      final temporary = GameState(store);
      final loading = temporary.initialize();
      temporary.dispose();
      await expectLater(loading, completes);
    },
  );

  test(
    'resume remembers the last ladder and supports older v5 saves',
    () async {
      expect(state.resumeLevel, isNull);
      for (final world in [6, 7]) {
        final progress = await completedLevel(state, world, 2);
        progress.currentRung = 1;
        await state.persistLevelState(progress);
      }
      expect(state.resumeLevel?.world, 7);
      expect(state.resumeLevel?.level, 2);
      await state.initialize(force: true);
      expect(state.resumeLevel?.world, 7);
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('lastPlayedWorld');
      await preferences.remove('lastPlayedLevel');
      expect(state.resumeLevel?.world, 6);
      expect(state.resumeLevel?.level, 2);
    },
  );

  test('resume offers the next ladder after a completion', () async {
    await state.persistLevelState(await completedLevel(state, 6, 50));
    expect(state.resumeLevel?.world, 7);
    expect(state.resumeLevel?.level, 1);
  });

  test('haptic preference survives loading saved progress again', () async {
    expect(state.hapticsEnabled, isTrue);
    await state.setHapticsEnabled(false);
    await state.initialize(force: true);
    expect(state.hapticsEnabled, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool('hapticsEnabled'),
      isFalse,
    );
    await state.reset();
    expect(state.hapticsEnabled, isFalse);
  });

  test(
    'progress survives reload and completion counts reflect a restart',
    () async {
      final progress = await completedLevel(state, 6, 1);
      progress.currentRung = 1;
      await state.persistLevelState(progress);
      expect(state.getWorldCompletionInfo(6).completedCount, 0);

      await state.initialize(force: true);
      final restored = state.getLevelState(6, 1);
      expect(restored.currentRung, 1);
      expect(restored.levelLetters, progress.levelLetters);

      progress.currentRung = progress.rungCount;
      await state.persistLevelState(progress);
      expect(state.getWorldCompletionInfo(6).completedCount, 1);
      expect(state.getWorldCompletionInfo(6).percent, 1 / 50);

      progress.currentRung = 0;
      await state.persistLevelState(progress);
      expect(state.getLevelState(6, 1).isWon, isFalse);
      expect(state.getWorldCompletionInfo(6).completedCount, 0);
      expect(state.getWorldCompletionInfo(6).percent, 0);
    },
  );

  test(
    'next level skips completed levels and crosses difficulty boundaries',
    () async {
      await state.persistLevelState(await completedLevel(state, 6, 2));
      await state.persistLevelState(await completedLevel(state, 6, 3));
      final next = state.getNextUnfinishedLevel(6, 1);
      expect(next?.world, 6);
      expect(next?.level, 4);

      final nextWorld = state.getNextUnfinishedLevel(6, 50);
      expect(nextWorld?.world, 7);
      expect(nextWorld?.level, 1);

      await state.persistLevelState(await completedLevel(state, 7, 1));
      expect(state.getNextUnfinishedLevel(6, 50)?.level, 2);
      expect(state.getNextUnfinishedLevel(10, 50), isNull);
    },
  );

  test('unlocking loads 250 levels without losing existing progress', () async {
    await state.persistLevelState(await completedLevel(state, 6, 1));
    final reloaded = Completer<void>();
    void onReload() {
      if (!reloaded.isCompleted) {
        reloaded.complete();
      }
    }

    state.addListener(onReload);
    store.unlockLevels();
    await reloaded.future.timeout(const Duration(seconds: 5));
    state.removeListener(onReload);

    expect(state.maxLevelsPerWorld, 250);
    expect(state.shouldAdverstiseMoreLevels, isFalse);
    for (final world in GameState.worldIds) {
      expect(state.getWorldLevelCount(world), 250);
      expect(state.getWorldCompletionInfo(world).levelCount, 250);
      expect((await state.getLevelOrLoad(world, 250)).letterCount, world);
    }
    expect(state.getLevelState(6, 1).isWon, isTrue);
    expect(state.getWorldCompletionInfo(6).completedCount, 1);
    expect(state.getWorldCompletionInfo(6).percent, 1 / 250);
    await expectLater(state.getLevelOrLoad(6, 251), throwsRangeError);
    final next = state.getNextUnfinishedLevel(6, 50);
    expect(next?.world, 6);
    expect(next?.level, 51);
    expect(state.getNextUnfinishedLevel(6, 100)?.level, 101);
    expect(state.getNextUnfinishedLevel(6, 200)?.level, 201);
    expect(state.getNextUnfinishedLevel(6, 249)?.level, 250);
    expect(state.getNextUnfinishedLevel(6, 250)?.world, 7);
    expect(state.getNextUnfinishedLevel(6, 250)?.level, 1);
    expect(state.getNextUnfinishedLevel(10, 250), isNull);

    for (final level in [100, 101, 200, 201, 250]) {
      await state.persistLevelState(await completedLevel(state, 6, level));
    }
    await state.initialize(force: true);
    for (final level in [1, 100, 101, 200, 201, 250]) {
      expect(state.getLevelState(6, level).isWon, isTrue);
    }
    expect(state.getWorldCompletionInfo(6).completedCount, 6);
    expect(state.getWorldCompletionInfo(6).percent, 6 / 250);

    final preferences = await SharedPreferences.getInstance();
    for (final level in [145, 146]) {
      final ladder = await state.getLevelOrLoad(6, level);
      final oldRungs = ladder.getBottomUp().skip(1).toList();
      await LevelState(
        6,
        level,
        6,
        level == 145 ? 2 : 1,
        2,
        oldRungs.map((rung) => rung.words.first.split('')).toList(),
      ).save(preferences);
    }
    await state.initialize(force: true);
    final completedShort = state.getLevelState(6, 145);
    expect(completedShort.isWon, isTrue);
    expect(completedShort.rungCount, 3);
    expect(completedShort.levelLetters, hasLength(3));
    final unfinishedShort = state.getLevelState(6, 146);
    expect(unfinishedShort.isWon, isFalse);
    expect(unfinishedShort.currentRung, 0);
    expect(unfinishedShort.rungCount, 3);
    expect(unfinishedShort.levelLetters.map((row) => row.length), [4, 5, 6]);
    expect(state.getWorldCompletionInfo(6).completedCount, 7);
  });

  test('reset removes saved progress and clears completion counts', () async {
    await state.persistLevelState(await completedLevel(state, 6, 1));
    await state.persistLevelState(await completedLevel(state, 7, 2));

    await state.reset();

    expect(state.getLevelState(6, 1).isEmpty, isTrue);
    expect(state.getLevelState(7, 2).isEmpty, isTrue);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    for (final world in GameState.worldIds) {
      expect(state.getWorldCompletionInfo(world).completedCount, 0);
      expect(state.getWorldLevelCount(world), 50);
    }
    expect(state.isGameDone(), isFalse);
  });

  test(
    'the game is only complete after every difficulty is finished',
    () async {
      for (final world in GameState.worldIds) {
        for (var level = 1; level <= state.maxLevelsPerWorld; level++) {
          await state.persistLevelState(
            await completedLevel(state, world, level),
          );
        }
        expect(state.isWorldDone(world), isTrue);
        expect(state.isGameDone(), world == GameState.worldIds.last);
      }
      expect(state.getNextUnfinishedLevel(6, 1), isNull);
    },
  );
}
