import 'dart:async';

import 'package:anagram_ladder/models/gameState.dart';
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
  final ladder = await state.getLevelOrLoad(world, level);
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

  test('unlocking loads 100 levels without losing existing progress', () async {
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

    expect(state.maxLevelsPerWorld, 100);
    expect(state.shouldAdverstiseMoreLevels, isFalse);
    for (final world in GameState.worldIds) {
      expect(state.getWorldLevelCount(world), 100);
    }
    expect(state.getLevelState(6, 1).isWon, isTrue);
    expect(state.getWorldCompletionInfo(6).completedCount, 1);
    expect(state.getWorldCompletionInfo(6).percent, 1 / 100);
    final next = state.getNextUnfinishedLevel(6, 50);
    expect(next?.world, 6);
    expect(next?.level, 51);
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
