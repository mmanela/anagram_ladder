import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LevelState {
  int world = -1;
  int level = -1;
  int maxWordLength = -1;
  int rungCount = -1;
  int currentRung = 0;
  List<List<String>> levelLetters = List.empty();

  double get percentComplete => currentRung / rungCount;
  bool get isWon => rungCount == currentRung;

  bool get isEmpty => world == -1 || level == -1;

  String getPrefKey(int world, int level, String key) =>
      "v5_${world}_${level}_$key";

  LevelState(
    this.world,
    this.level,
    this.maxWordLength,
    this.currentRung,
    this.rungCount,
    this.levelLetters,
  );

  LevelState.empty();

  Map<String, Object> toJson() => {
    'world': world,
    'level': level,
    'maxWordLength': maxWordLength,
    'currentRung': currentRung,
    'rungCount': rungCount,
    'levelLetters': levelLetters,
  };

  factory LevelState.fromJson(Map<String, dynamic> json) {
    final world = json['world'];
    final level = json['level'];
    final maxWordLength = json['maxWordLength'];
    final currentRung = json['currentRung'];
    final rungCount = json['rungCount'];
    final rows = json['levelLetters'];
    if (world is! int ||
        world < 1 ||
        level is! int ||
        level < 1 ||
        maxWordLength is! int ||
        maxWordLength < 0 ||
        currentRung is! int ||
        currentRung < 0 ||
        rungCount is! int ||
        rungCount < 1 ||
        currentRung > rungCount ||
        rows is! List ||
        rows.length != rungCount) {
      throw const FormatException('Invalid daily ladder progress');
    }
    final letters = <List<String>>[];
    for (final row in rows) {
      if (row is! List ||
          row.isEmpty ||
          row.any(
            (letter) =>
                letter is! String || !RegExp(r'^[a-z]?$').hasMatch(letter),
          )) {
        throw const FormatException('Invalid daily ladder letters');
      }
      letters.add(row.cast<String>().toList());
    }
    return LevelState(
      world,
      level,
      maxWordLength,
      currentRung,
      rungCount,
      letters,
    );
  }

  LevelState.fromSharedPreferences(
    int world,
    int level,
    SharedPreferences prefs,
  ) {
    int? worldRaw = prefs.getInt(getPrefKey(world, level, "world"));
    int? levelRaw = prefs.getInt(getPrefKey(world, level, "level"));
    if (worldRaw == null ||
        levelRaw == null ||
        world != worldRaw ||
        level != levelRaw) {
      // no valid state here so bail out
      return;
    }
    this.world = world;
    this.level = level;
    this.maxWordLength =
        prefs.getInt(getPrefKey(world, level, "maxWordLength")) ?? 0;
    this.rungCount = prefs.getInt(getPrefKey(world, level, "rungCount")) ?? 0;
    this.currentRung =
        prefs.getInt(getPrefKey(world, level, "currentRung")) ?? 0;
    var lettersRaw = jsonDecode(
      prefs.getString(getPrefKey(world, level, "levelLetters")) ?? "",
    ) as List<dynamic>;
    this.levelLetters = lettersRaw
        .map((x) => (x as List<dynamic>).cast<String>())
        .toList();
  }

  Future save(SharedPreferences prefs) async {
    await prefs.setInt(getPrefKey(world, level, "world"), world);
    await prefs.setInt(getPrefKey(world, level, "level"), level);
    await prefs.setInt(
      getPrefKey(world, level, "maxWordLength"),
      maxWordLength,
    );
    await prefs.setInt(getPrefKey(world, level, "rungCount"), rungCount);
    await prefs.setInt(getPrefKey(world, level, "currentRung"), currentRung);
    await prefs.setString(
      getPrefKey(world, level, "levelLetters"),
      jsonEncode(levelLetters),
    );
  }
}
