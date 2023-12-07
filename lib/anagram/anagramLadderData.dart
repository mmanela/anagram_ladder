import 'dart:convert';
import 'package:anagram_ladder/anagram/anagramBuilder.dart';

import 'ladderLevel.dart';
import 'package:flutter/services.dart' show rootBundle;

class AnagramLadderData {
  static Future<List<LadderLevel>> getLadders(int length) async {
    final path = AnagramLadderBuilder.getGameLadderSetPath(length);
    final json = await rootBundle.loadString(path);
    final rawModel = jsonDecode(json) as List<dynamic>;
    return rawModel.map((e) => LadderLevel.fromJson(e)).toList();
  }
}
