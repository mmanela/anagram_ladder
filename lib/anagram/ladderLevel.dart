class LadderLevel implements Comparable<LadderLevel> {
  final List<String> letters;

  // All possible words for this level
  final int levelWordCount;

  // All possible words for this level and levels below
  final int totalWordCount;
  final int rung;

  final LadderLevel? childLevel;
  final List<String> words;
  List<String> lettersToAdd = List.empty();

  int get letterCount => letters.length;
  double get wordsPerLadder => totalWordCount / (rung + 1.0);

  LadderLevel(
      this.letters, this.levelWordCount, LadderLevel childLevel, this.words)
      : totalWordCount = childLevel.totalWordCount + levelWordCount,
        rung = childLevel.rung + 1,
        this.childLevel = childLevel {
    lettersToAdd = _intersect(childLevel.letters, this.letters);
  }

  LadderLevel.bottom(this.letters, this.levelWordCount, this.words)
      : totalWordCount = levelWordCount,
        rung = 0,
        childLevel = null;

  // Assume they are sorted
  List<String> _intersect(List<String> from, List<String> to) {
    final res = List<String>.from(to);
    from.forEach((e) {
      res.remove(e);
    });
    return res;
  }

  LadderLevel.fromJson(Map<String, dynamic> json)
      : letters = json['letters'].cast<String>(),
        lettersToAdd = json['lettersToAdd'].cast<String>(),
        rung = json['rung'],
        levelWordCount = json['levelWordCount'],
        totalWordCount = json['totalWordCount'],
        words = json['words'].cast<String>(),
        childLevel = json['childLevel'] != null
            ? LadderLevel.fromJson(json['childLevel'])
            : null;

  Map<String, dynamic> toJson() {
    return {
      'letters': letters,
      'lettersToAdd': lettersToAdd,
      'rung': rung,
      'levelWordCount': levelWordCount,
      'totalWordCount': totalWordCount,
      'words': words,
      'childLevel': childLevel?.toJson()
    };
  }

  LadderLevel getBottom() {
    LadderLevel? bottom = this;
    while (bottom!.childLevel != null) {
      bottom = bottom.childLevel;
    }
    return bottom;
  }

  List<LadderLevel> getBottomUp() {
    List<LadderLevel> levels = List.empty(growable: true);
    levels.add(this);
    LadderLevel? bottom = this;
    while (bottom!.childLevel != null) {
      bottom = bottom.childLevel;
      levels.add(bottom!);
    }
    return levels.reversed.toList();
  }

  @override
  String toString() {
    String childStr = "";
    if (childLevel != null) {
      childStr = childLevel.toString();
    }

    return '''
    Letters:${letters.join()},  Word:${words.take(5)}, LettersToAdd:${lettersToAdd.join()} Rung:$rung, LevelWordCount:$levelWordCount, TotalWordCount:$totalWordCount,
    $childStr''';
  }

  // Comparison favors "easier" meaning more
  // options of words
  @override
  int compareTo(LadderLevel other) {
    if (letters.length != other.letters.length) {
      return letters.length - other.letters.length;
    }
    if (rung != other.rung) {
      return other.rung - rung;
    }
    if (totalWordCount != other.totalWordCount) {
      return other.totalWordCount - totalWordCount;
    }
    if (wordsPerLadder != other.wordsPerLadder) {
      return (other.wordsPerLadder - wordsPerLadder).round();
    }
    if (levelWordCount != other.levelWordCount) {
      return other.levelWordCount - levelWordCount;
    }
    return other.levelWordCount - levelWordCount;
  }
}
