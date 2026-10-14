import 'dart:async';
import 'dart:math';

import 'package:anagram_ladder/anagram/anagramBuilder.dart';
import 'package:anagram_ladder/anagram/anagramLadderData.dart';
import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:more/collection.dart';

class WorldCompletionInfo {
  int levelCount;
  int completedCount;

  WorldCompletionInfo(this.levelCount, this.completedCount);
  WorldCompletionInfo.empty() : this(0, 0);

  double get percent => completedCount / levelCount;
}

class GameState with ChangeNotifier {
  final GameStore gameStore;
  SharedPreferences? _sharedPreferences;
  final Map<int, List<LadderLevel>> _ladders = Map();
  static const DefaultLevelsPerWorld = 50;
  static const UnlockedLevelsPerWorld = 100;
  int maxLevelsPerWorld = DefaultLevelsPerWorld;
  final Map<int, WorldCompletionInfo> _worldCompletionInfo = Map();
  bool get shouldAdverstiseMoreLevels =>
      _shouldAdverstiseMoreLevels &&
      defaultTargetPlatform != TargetPlatform.android;
  bool _shouldAdverstiseMoreLevels = false;

  static final Map<int, String> worldLabels = {
    6: "Normal",
    7: "Hard",
    8: "Daunting",
    9: "Expert",
    10: "Genius",
  };
  static final worldIds = IntegerRange(
    AnagramLadderBuilder.SeedWordLengthMin,
    AnagramLadderBuilder.SeedWordLengthMax + 1,
  ).toList();
  bool isLoaded = false;
  bool _disposed = false;

  bool get hapticsEnabled =>
      _sharedPreferences?.getBool('hapticsEnabled') ?? true;

  Future<void> setHapticsEnabled(bool enabled) async {
    final preferences = _sharedPreferences;
    if (preferences == null) throw StateError('Game is not loaded');
    await preferences.setBool('hapticsEnabled', enabled);
    if (!_disposed) notifyListeners();
  }

  GameRoutePath? get resumeLevel {
    final world = _sharedPreferences?.getInt('lastPlayedWorld');
    final level = _sharedPreferences?.getInt('lastPlayedLevel');
    if (worldIds.contains(world) &&
        level != null &&
        level >= 1 &&
        level <= getWorldLevelCount(world!)) {
      final saved = getLevelState(world, level);
      if (!saved.isEmpty && !saved.isWon) {
        return GameRoutePath.level(world, level);
      }
      final next = getNextUnfinishedLevel(world, level);
      if (next != null) {
        return next;
      }
    }
    for (final world in worldIds) {
      for (var level = 1; level <= getWorldLevelCount(world); level++) {
        final saved = getLevelState(world, level);
        if (!saved.isEmpty && !saved.isWon) {
          return GameRoutePath.level(world, level);
        }
      }
    }
    return null;
  }

  GameState(this.gameStore) {
    this.gameStore.addListener(_handleStoreChange);
    _setMaxLevelCount();
  }

  @override
  void dispose() {
    _disposed = true;
    this.gameStore.removeListener(_handleStoreChange);
    super.dispose();
  }

  void _handleStoreChange() {
    _setMaxLevelCount();
  }

  Future _setMaxLevelCount() async {
    int newLevelCount;
    if (this.gameStore.hasUnlocked51To100) {
      newLevelCount = UnlockedLevelsPerWorld;
      _shouldAdverstiseMoreLevels = false;
    } else {
      newLevelCount = DefaultLevelsPerWorld;
      _shouldAdverstiseMoreLevels = true;
    }

    if (newLevelCount != maxLevelsPerWorld) {
      maxLevelsPerWorld = newLevelCount;
      await initialize(force: true);
    }
  }

  Future initialize({bool force = false}) async {
    print("gameState: Start initialize");

    try {
      _worldCompletionInfo.clear();
      if (_sharedPreferences == null) {
        _sharedPreferences = await SharedPreferences.getInstance();
      }
      for (var worldId in worldIds) {
        await getWorldOrLoad(worldId, force: force);
        _updateWorldCompletionPercentage(worldId);
      }
    } finally {
      print("gameState: End initialize");
      isLoaded = true;
      if (!_disposed) notifyListeners();
    }
  }

  void _updateWorldCompletionPercentage(int worldNum) {
    final world = _ladders[worldNum];
    int worldLevelCount = 0;
    int completes = 0;
    if (world != null) {
      worldLevelCount = min(world.length, maxLevelsPerWorld);
      for (int i = 0; i < worldLevelCount; i++) {
        final lstate = getLevelState(worldNum, i + 1);
        if (lstate.isWon) {
          completes++;
        }
      }
    }

    _worldCompletionInfo[worldNum] = WorldCompletionInfo(
      worldLevelCount,
      completes,
    );
  }

  WorldCompletionInfo getWorldCompletionInfo(int worldNum) {
    return _worldCompletionInfo[worldNum] ?? WorldCompletionInfo.empty();
  }

  Future<List<LadderLevel>> getWorldOrLoad(
    int length, {
    bool force = false,
  }) async {
    if (_ladders.containsKey(length) && !force) {
      // No need to load more than once
      return Future.value(_ladders[length]);
    }
    final world = (await AnagramLadderData.getLadders(length))
        .take(maxLevelsPerWorld)
        .toList();
    _ladders[length] = world;
    return world;
  }

  Future<LadderLevel> getLevelOrLoad(int worldNum, int level) async {
    final world = await getWorldOrLoad(worldNum);
    return world[level - 1];
  }

  int getWorldLevelCount(int worldNum) {
    if (_ladders[worldNum] == null) {
      return 0;
    }

    return _ladders[worldNum]!.length;
  }

  LevelState getLevelState(int world, int level) {
    if (_sharedPreferences != null) {
      return LevelState.fromSharedPreferences(
        world,
        level,
        _sharedPreferences!,
      );
    }

    return LevelState.empty();
  }

  Future persistLevelState(LevelState levelState) async {
    final previous = getLevelState(levelState.world, levelState.level);
    final previousResume = resumeLevel;
    if (_sharedPreferences != null) {
      await levelState.save(_sharedPreferences!);
      await _sharedPreferences!.setInt('lastPlayedWorld', levelState.world);
      await _sharedPreferences!.setInt('lastPlayedLevel', levelState.level);
    }

    _updateWorldCompletionPercentage(levelState.world);
    if (!_disposed &&
        (previous.isEmpty ||
            previous.currentRung != levelState.currentRung ||
            previousResume?.world != levelState.world ||
            previousResume?.level != levelState.level)) {
      notifyListeners();
    }
  }

  bool isWorldDone(int world) {
    final info = getWorldCompletionInfo(world);
    return info.completedCount >= info.levelCount;
  }

  bool isGameDone() {
    for (var worldId in worldIds) {
      if (!isWorldDone(worldId)) {
        return false;
      }
    }
    return true;
  }

  GameRoutePath? getNextUnfinishedLevel(int world, int level) {
    final lastWorldId = worldIds.last;
    do {
      if (level < maxLevelsPerWorld) {
        level++;
      } else if (world < lastWorldId) {
        level = 1;
        world++;
      } else {
        break;
      }

      if (!getLevelState(world, level).isWon) {
        return GameRoutePath.level(world, level);
      }
    } while (level <= maxLevelsPerWorld && world <= lastWorldId);

    return null;
  }

  Future reset() async {
    final preferences = _sharedPreferences;
    if (preferences != null) {
      for (final key in preferences.getKeys()) {
        if (key.startsWith('v5_') ||
            key == 'lastPlayedWorld' ||
            key == 'lastPlayedLevel') {
          await preferences.remove(key);
        }
      }
    }

    await initialize();
  }
}
