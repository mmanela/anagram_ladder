import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/dailyChallenge.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/pages/aboutPage.dart';
import 'package:anagram_ladder/pages/homePage.dart';
import 'package:anagram_ladder/pages/levelPage.dart';
import 'package:anagram_ladder/pages/loadingPage.dart';
import 'package:anagram_ladder/pages/payPage.dart';
import 'package:anagram_ladder/pages/settingsPage.dart';
import 'package:anagram_ladder/pages/unknownPage.dart';
import 'package:anagram_ladder/pages/worldPage.dart';
import 'package:anagram_ladder/pages/worldSet.dart';
import 'package:flutter/material.dart';

import 'gameRoutePath.dart';

class GameRouterDelegate extends RouterDelegate<GameRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<GameRoutePath> {
  final GlobalKey<NavigatorState> _navigatorKey;
  final GameRouteNavigator _routeNavigator;
  final GameState _gameState;
  final GameStore _gameStore;
  GameRouterDelegate(this._routeNavigator, this._gameState, this._gameStore)
    : _navigatorKey = GlobalKey<NavigatorState>() {
    _routeNavigator.addListener(_handleChange);
    _gameState.addListener(_handleChange);
    _gameStore.addListener(notifyListeners);
    _handleChange();
  }

  void _handleChange() {
    if (_gameState.isLoaded &&
        _routeNavigator.current.page == GameRoutePage.Daily) {
      _routeNavigator.goto(GameRoutePath.dailyLevel(_gameState.today.dateKey));
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _routeNavigator.removeListener(_handleChange);
    _gameState.removeListener(_handleChange);
    _gameStore.removeListener(notifyListeners);
    super.dispose();
  }

  GameRoutePath get currentConfiguration {
    final path = _routeNavigator.current;
    if (_gameState.isLoaded && path.page == GameRoutePage.DailyLevel) {
      final challenge = DailyChallenge.tryParse(path.dailyDate ?? '');
      if (challenge == null ||
          challenge.date.isAfter(_gameState.today.date) ||
          (challenge.date.isBefore(_gameState.today.date) &&
              !_gameState.hasDailyProgress(challenge))) {
        return GameRoutePath.unknown();
      }
    }
    if (_gameState.isLoaded &&
        (path.page == GameRoutePage.World ||
            path.page == GameRoutePage.Level) &&
        (!GameState.worldIds.contains(path.world) ||
            (path.page == GameRoutePage.Level &&
                (path.level == null ||
                    path.level! < 1 ||
                    path.level! >
                        _gameState.getWorldLevelCount(path.world!))))) {
      return GameRoutePath.unknown();
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: !_gameState.isLoaded
          ? [MaterialPage(key: ValueKey('LoadingPage'), child: LoadingPage())]
          : [
              MaterialPage(key: ValueKey('HomePage'), child: HomePage()),
              if (currentConfiguration.page == GameRoutePage.DailyLevel)
                MaterialPage(
                  key: ValueKey('DailyLevelPage'),
                  child: LevelPage.daily(
                    _gameState.dailyForDate(
                      DailyChallenge.tryParse(currentConfiguration.dailyDate!)!
                          .date,
                    ),
                    key: ValueKey('daily-${currentConfiguration.dailyDate}'),
                  ),
                ),
              if (currentConfiguration.page == GameRoutePage.Unknown)
                MaterialPage(
                  key: ValueKey('UnknownPage'),
                  child: UnknownPage(),
                ),
              if (currentConfiguration.page == GameRoutePage.Settings)
                MaterialPage(
                  key: ValueKey('SettingsPage'),
                  child: SettingsPage(),
                ),
              if (currentConfiguration.page == GameRoutePage.About)
                MaterialPage(key: ValueKey('AboutPage'), child: AboutPage()),
              if (currentConfiguration.page == GameRoutePage.WorldSet ||
                  currentConfiguration.page == GameRoutePage.World ||
                  currentConfiguration.page == GameRoutePage.Level)
                MaterialPage(
                  key: ValueKey('WorldSetPage'),
                  child: WorldSetPage(),
                ),
              if (currentConfiguration.page == GameRoutePage.World ||
                  currentConfiguration.page == GameRoutePage.Level ||
                  currentConfiguration.source == GameRoutePage.World)
                MaterialPage(
                  key: ValueKey('WorldPage'),
                  child: WorldPage(currentConfiguration.world!),
                ),
              if (currentConfiguration.page == GameRoutePage.Level)
                MaterialPage(
                  key: ValueKey('LevelPage'),
                  child: LevelPage(
                    currentConfiguration.world!,
                    currentConfiguration.level!,
                    key: Key(
                      "${currentConfiguration.world!}_${currentConfiguration.level!}",
                    ),
                  ),
                ),
              if (currentConfiguration.page == GameRoutePage.Pay)
                MaterialPage(key: ValueKey('PayPage'), child: PayPage()),
            ],
      onDidRemovePage: (page) {
        // Declarative route changes also remove pages. Only handle user pops.
        final currentPageKey = switch (currentConfiguration.page) {
          GameRoutePage.Home => 'HomePage',
          GameRoutePage.Unknown => 'UnknownPage',
          GameRoutePage.About => 'AboutPage',
          GameRoutePage.Settings => 'SettingsPage',
          GameRoutePage.Pay => 'PayPage',
          GameRoutePage.WorldSet => 'WorldSetPage',
          GameRoutePage.World => 'WorldPage',
          GameRoutePage.Level => 'LevelPage',
          GameRoutePage.Daily => 'DailyLevelPage',
          GameRoutePage.DailyLevel => 'DailyLevelPage',
        };
        if (page.key != ValueKey(currentPageKey)) {
          return;
        }

        switch (currentConfiguration.page) {
          case GameRoutePage.Home:
            return;
          case GameRoutePage.Unknown:
          case GameRoutePage.About:
          case GameRoutePage.WorldSet:
          case GameRoutePage.Settings:
          case GameRoutePage.Daily:
          case GameRoutePage.DailyLevel:
            _routeNavigator.goto(GameRoutePath.home());
            break;
          case GameRoutePage.Pay:
            if (currentConfiguration.source == GameRoutePage.World) {
              _routeNavigator.goto(
                GameRoutePath.world(currentConfiguration.world!),
              );
            } else {
              _routeNavigator.goto(GameRoutePath.home());
            }
            break;
          case GameRoutePage.World:
            _routeNavigator.goto(GameRoutePath.worldSet());
            break;
          case GameRoutePage.Level:
            _routeNavigator.goto(
              GameRoutePath.world(currentConfiguration.world!),
            );
            break;
        }
      },
    );
  }

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  @override
  Future<void> setNewRoutePath(GameRoutePath path) async {
    _routeNavigator.goto(path);
  }
}
