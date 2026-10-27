import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:anagram_ladder/anagram/anagramBuilder.dart';
import 'package:anagram_ladder/anagram/anagramLadderData.dart';
import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:anagram_ladder/models/dailyChallenge.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:more/collection.dart';

class WorldCompletionInfo {
  int levelCount;
  int completedCount;

  WorldCompletionInfo(this.levelCount, this.completedCount);
  WorldCompletionInfo.empty() : this(0, 0);

  double get percent => completedCount / levelCount;
}

class GameState with ChangeNotifier, WidgetsBindingObserver {
  final GameStore gameStore;
  SharedPreferences? _sharedPreferences;
  final Map<int, List<LadderLevel>> _ladders = Map();
  final Map<int, List<LadderLevel>> _allLadders = {};
  static const DefaultLevelsPerWorld = 50;
  static const UnlockedLevelsPerWorld = 250;
  int maxLevelsPerWorld = DefaultLevelsPerWorld;
  final Map<int, WorldCompletionInfo> _worldCompletionInfo = Map();
  bool get shouldAdverstiseMoreLevels =>
      _shouldAdverstiseMoreLevels &&
      defaultTargetPlatform != TargetPlatform.android;
  bool _shouldAdverstiseMoreLevels = false;

  static const worldLabels = DailyChallenge.difficulties;
  static final worldIds = IntegerRange(
    AnagramLadderBuilder.SeedWordLengthMin,
    AnagramLadderBuilder.SeedWordLengthMax + 1,
  ).toList();
  bool isLoaded = false;
  bool _disposed = false;
  final DateTime Function() _now;
  late DailyChallenge _today;
  Timer? _dailyTimer;

  DailyChallenge get today => dailyForDate(_today.date);

  DailyChallenge dailyForDate(DateTime date) {
    final challenge = DailyChallenge(date);
    if (_sharedPreferences?.containsKey(
              'daily_v1_progress_${challenge.dateKey}',
            ) ==
            true ||
        _sharedPreferences?.containsKey(
              'daily_v1_completed_${challenge.dateKey}',
            ) ==
            true) {
      return DailyChallenge.legacy(date);
    }
    if (_sharedPreferences?.containsKey(
              'daily_v2_progress_${challenge.dateKey}',
            ) ==
            true ||
        _sharedPreferences?.containsKey(
              'daily_v2_completed_${challenge.dateKey}',
            ) ==
            true) {
      return DailyChallenge.previous(date);
    }
    return challenge;
  }

  String _dailyKey(DailyChallenge challenge, String part) {
    final selected = dailyForDate(challenge.date);
    final version = selected.isLegacy
        ? 'v1'
        : selected.isPrevious
        ? 'v2'
        : 'v3';
    return 'daily_${version}_${part}_${selected.dateKey}';
  }

  void refreshDaily() {
    if (_disposed) return;
    final now = _now();
    final today = DailyChallenge(now);
    final changed = today.dateKey != _today.dateKey;
    _today = today;
    _dailyTimer?.cancel();
    final midnight = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    _dailyTimer = Timer(midnight.difference(now), refreshDaily);
    if (changed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshDaily();
  }

  bool hasDailyProgress(DailyChallenge challenge) =>
      _sharedPreferences?.containsKey(_dailyKey(challenge, 'progress')) ??
      false;

  bool isDailyCompleted(DailyChallenge challenge) =>
      _sharedPreferences?.getBool(_dailyKey(challenge, 'completed')) ?? false;

  LevelState getDailyState(DailyChallenge challenge) {
    final selected = dailyForDate(challenge.date);
    final raw = _sharedPreferences?.getString(_dailyKey(selected, 'progress'));
    if (raw == null) return LevelState.empty();
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid daily ladder save');
    }
    final progress = LevelState.fromJson(json);
    if (progress.world != selected.world || progress.level != selected.level) {
      throw const FormatException('Daily save does not match its puzzle');
    }
    return progress;
  }

  Future<void> persistDailyState(
    DailyChallenge challenge,
    LevelState progress,
  ) async {
    final preferences = _sharedPreferences;
    if (preferences == null) throw StateError('Game is not loaded');
    final selected = dailyForDate(challenge.date);
    if (progress.world != selected.world || progress.level != selected.level) {
      throw ArgumentError('Daily progress must match its puzzle');
    }
    final previous = getDailyState(challenge);
    final completedBefore = isDailyCompleted(challenge);
    if (!await preferences.setString(
      _dailyKey(selected, 'progress'),
      jsonEncode(progress.toJson()),
    )) {
      throw StateError('Could not save daily progress');
    }
    if (progress.isWon && !completedBefore) {
      if (!await preferences.setBool(_dailyKey(selected, 'completed'), true)) {
        throw StateError('Could not save daily completion');
      }
    }
    if (!_disposed &&
        (previous.isEmpty ||
            previous.currentRung != progress.currentRung ||
            (!completedBefore && progress.isWon))) {
      notifyListeners();
    }
  }

  bool get hapticsEnabled =>
      _sharedPreferences?.getBool('hapticsEnabled') ?? true;

  bool get controlsLearned =>
      _sharedPreferences?.getBool('controlsLearned') ?? false;

  Future<void> markControlsLearned() async {
    if (controlsLearned) return;
    final preferences = _sharedPreferences;
    if (preferences == null) throw StateError('Game is not loaded');
    if (!await preferences.setBool('controlsLearned', true)) {
      throw StateError('Could not save the controls preference');
    }
    if (!_disposed) notifyListeners();
  }

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

  GameState(this.gameStore, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _today = DailyChallenge(_now());
    WidgetsBinding.instance.addObserver(this);
    this.gameStore.addListener(_handleStoreChange);
    _setMaxLevelCount();
  }

  @override
  void dispose() {
    _disposed = true;
    _dailyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
      await _migrateRepairedLadderProgress(6, 98);
      for (final (world, level) in LevelState.catalogRepairs.keys) {
        await _migrateRepairedLadderProgress(world, level);
      }
      for (var worldId in worldIds) {
        await getWorldOrLoad(worldId, force: force);
        if (_ladders[worldId]!.asMap().keys.any(
          (index) => getLevelState(worldId, index + 1).rungCount == 2,
        )) {
          await _migrateShortLadderProgress(worldId);
        }
        _updateWorldCompletionPercentage(worldId);
      }
    } finally {
      print("gameState: End initialize");
      isLoaded = true;
      if (!_disposed) refreshDaily();
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _migrateShortLadderProgress(int world) async {
    final preferences = _sharedPreferences!;
    final ladders = _ladders[world]!;
    for (var index = 0; index < ladders.length; index++) {
      final saved = getLevelState(world, index + 1);
      if (saved.isEmpty || saved.rungCount != 2) continue;
      final rungs = ladders[index].getBottomUp();
      if (rungs.length < AnagramLadderBuilder.MinimumRungCount) continue;
      final rows = rungs.map((rung) {
        if (!saved.isWon) return List.filled(rung.letterCount, '');
        final oldAnswer = saved.levelLetters
            .map((letters) => letters.join())
            .firstWhere(rung.words.contains, orElse: () => rung.words.first);
        return oldAnswer.split('');
      }).toList();
      if (!saved.isWon) rows[0] = List.of(rungs.first.letters)..shuffle();
      await LevelState(
        world,
        index + 1,
        saved.isWon ? ladders[index].letterCount : 0,
        saved.isWon ? rungs.length : 0,
        rungs.length,
        rows,
      ).save(preferences);
      debugPrint(
        'Ladder: upgraded short puzzle $world/${index + 1}; '
        '${saved.isWon ? 'completion preserved' : 'in-progress ladder restarted'}',
      );
    }
  }

  Future<void> _migrateRepairedLadderProgress(int world, int level) async {
    final preferences = _sharedPreferences!;
    final regular = getLevelState(world, level);
    if (!regular.isEmpty) {
      final key = regular.getPrefKey(world, level, 'levelLetters');
      final raw = preferences.getString(key)!;
      final encoded = jsonEncode(regular.levelLetters);
      if (encoded != jsonEncode(jsonDecode(raw))) {
        if (!await preferences.setString(key, encoded)) {
          throw StateError('Could not save repaired $world/$level progress');
        }
        debugPrint('Ladder: repaired $world/$level progress');
      }
    }
    for (final key in preferences.getKeys()) {
      final match = RegExp(r'^daily_v([123])_progress_(.+)$').firstMatch(key);
      if (match == null) continue;
      final parsed = DailyChallenge.tryParse(match[2]!);
      if (parsed == null) continue;
      final day = switch (match[1]) {
        '1' => DailyChallenge.legacy(parsed.date),
        '2' => DailyChallenge.previous(parsed.date),
        _ => parsed,
      };
      if (day.world != world || day.level != level) continue;
      final raw = jsonDecode(preferences.getString(key)!);
      if (raw is! Map<String, dynamic> ||
          raw['world'] != world ||
          raw['level'] != level) {
        throw const FormatException(
          'Repaired daily save does not match its puzzle',
        );
      }
      final repaired = LevelState.fromJson(raw);
      final encoded = jsonEncode(repaired.toJson());
      if (encoded == jsonEncode(raw)) continue;
      if (!await preferences.setString(key, encoded)) {
        throw StateError(
          'Could not save repaired $world/$level daily progress',
        );
      }
      debugPrint('Ladder: repaired $world/$level daily progress');
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
    final all = await AnagramLadderData.getLadders(length);
    _allLadders[length] = all;
    final world = all.take(maxLevelsPerWorld).toList();
    _ladders[length] = world;
    return world;
  }

  Future<LadderLevel> getLevelOrLoad(int worldNum, int level) async {
    final world = await getWorldOrLoad(worldNum);
    return world[level - 1];
  }

  Future<LadderLevel> getDailyLadder(DailyChallenge challenge) async {
    final selected = dailyForDate(challenge.date);
    final ladders =
        _allLadders[selected.world] ??
        await AnagramLadderData.getLadders(selected.world);
    return ladders[selected.level - 1];
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
            key.startsWith('daily_v1_') ||
            key.startsWith('daily_v2_') ||
            key.startsWith('daily_v3_') ||
            key == 'lastPlayedWorld' ||
            key == 'lastPlayedLevel') {
          await preferences.remove(key);
        }
      }
    }

    await initialize();
  }
}
