class DailyChallenge {
  static const difficulties = {
    6: 'Normal',
    7: 'Hard',
    8: 'Daunting',
    9: 'Expert',
    10: 'Genius',
  };
  static const levelsPerDifficulty = 250;
  static const puzzleCount = levelsPerDifficulty * 5;
  static final _puzzleOrder = _shufflePuzzles();
  static final _previousPuzzleOrder = _shufflePuzzles(250);
  final DateTime date;
  final bool isLegacy;
  final bool isPrevious;

  DailyChallenge(DateTime day) : this._(day, false, false);

  DailyChallenge.legacy(DateTime day) : this._(day, true, false);

  DailyChallenge.previous(DateTime day) : this._(day, false, true);

  DailyChallenge._(DateTime day, this.isLegacy, this.isPrevious)
    : date = DateTime.utc(day.year, day.month, day.day);

  static List<int> _shufflePuzzles([int count = puzzleCount]) {
    final order = List.generate(count, (index) => index);
    var seed = 888;
    for (var index = order.length - 1; index > 0; index--) {
      // Keep the schedule identical on native platforms and the web.
      seed = seed * 48271 % 2147483647;
      final other = seed % (index + 1);
      final value = order[index];
      order[index] = order[other];
      order[other] = value;
    }
    return List<int>.unmodifiable(order);
  }

  static DailyChallenge? tryParse(String key) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) return null;
    final parsed = DateTime.tryParse(key);
    if (parsed == null || parsed.year < 1) return null;
    final challenge = DailyChallenge(parsed);
    return challenge.dateKey == key ? challenge : null;
  }

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  int get dayNumber => date.difference(DateTime.utc(2026)).inDays;
  int get _levelCount => isLegacy || isPrevious ? 50 : levelsPerDifficulty;
  int get _puzzleIndex => isPrevious
      ? _previousPuzzleOrder[dayNumber % _previousPuzzleOrder.length]
      : _puzzleOrder[dayNumber % puzzleCount];
  int get world =>
      isLegacy ? 6 : difficulties.keys.elementAt(_puzzleIndex ~/ _levelCount);
  int get level =>
      isLegacy ? dayNumber % _levelCount + 1 : _puzzleIndex % _levelCount + 1;
  String get difficulty => difficulties[world]!;
  String get difficultyDescription => '$difficulty, up to $world letters';

  String shareText(List<int> wordLengths) => [
    'Anagram Ladder | Daily $dateKey',
    '$difficulty | ${wordLengths.length}/${wordLengths.length} rungs solved',
    for (final length in wordLengths) List.filled(length, '\u{1F7E9}').join(),
    'https://matthewmanela.com/anagram-ladder/',
  ].join('\n');
}
