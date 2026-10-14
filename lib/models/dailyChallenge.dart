class DailyChallenge {
  static const world = 6;
  static const puzzleCount = 50;
  final DateTime date;

  DailyChallenge(DateTime day)
    : date = DateTime.utc(day.year, day.month, day.day);

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
  int get level => dayNumber % puzzleCount + 1;

  String shareText(List<int> wordLengths) => [
    'Anagram Ladder | Daily $dateKey',
    'Normal | ${wordLengths.length}/${wordLengths.length} rungs solved',
    for (final length in wordLengths) List.filled(length, '\u{1F7E9}').join(),
    'https://matthewmanela.com/anagram-ladder/',
  ].join('\n');
}
