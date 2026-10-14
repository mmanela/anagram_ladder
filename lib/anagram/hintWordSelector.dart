import 'package:flutter/services.dart';

import 'anagramBuilder.dart';

class HintWordSelector {
  static final shared = HintWordSelector();
  final AssetBundle _assets;
  Map<String, int>? _ranks;
  Future<Map<String, int>>? _loading;

  HintWordSelector({AssetBundle? assets}) : _assets = assets ?? rootBundle;

  Future<String> select(List<String> words) async {
    if (words.isEmpty)
      throw ArgumentError.value(words, 'words', 'Must not be empty');
    if (words.length == 1) return words.single;
    final Map<String, int> ranks;
    try {
      ranks = _ranks ?? await (_loading ??= _loadRanks());
    } catch (_) {
      _loading = null;
      rethrow;
    }
    var selected = words.first;
    for (final word in words.skip(1)) {
      if ((ranks[word] ?? 100) < (ranks[selected] ?? 100)) {
        selected = word;
      }
    }
    return selected;
  }

  Future<Map<String, int>> _loadRanks() async {
    final files = AnagramLadderBuilder.scowlEasyFileNames;
    final contents = await Future.wait(
      files.map(
        (file) => _assets.loadString(AnagramLadderBuilder.getScowlFile(file)),
      ),
    );
    final ranks = <String, int>{};
    for (var index = 0; index < files.length; index++) {
      final tier = int.parse(files[index].split('.').last);
      for (final line in contents[index].split('\n')) {
        final word = line.trim().toLowerCase();
        if (word.isNotEmpty && tier < (ranks[word] ?? 100)) {
          ranks[word] = tier;
        }
      }
    }
    _ranks = ranks;
    return ranks;
  }
}
