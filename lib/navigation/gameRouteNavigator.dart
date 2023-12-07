import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:flutter/material.dart';

class GameRouteNavigator with ChangeNotifier {
  GameRoutePath _currentPath = GameRoutePath.home();

  GameRoutePath get current => _currentPath;

  void goto(GameRoutePath path) {
    _currentPath = path;
    notifyListeners();
  }
}
