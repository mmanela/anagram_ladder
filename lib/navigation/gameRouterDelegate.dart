import 'package:anagram_ladder/models/gameState.dart';
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
    _routeNavigator.addListener(notifyListeners);
    _gameState.addListener(notifyListeners);
    _gameStore.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _routeNavigator.removeListener(notifyListeners);
    _gameState.removeListener(notifyListeners);
    _gameStore.removeListener(notifyListeners);
    super.dispose();
  }

  GameRoutePath get currentConfiguration => _routeNavigator.current;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: !_gameState.isLoaded || !_gameStore.isLoaded
          ? [
              MaterialPage(
                key: ValueKey('LoadingPage'),
                child: LoadingPage(),
              )
            ]
          : [
              MaterialPage(
                key: ValueKey('HomePage'),
                child: HomePage(),
              ),
              if (currentConfiguration.page == GameRoutePage.Unknown)
                MaterialPage(
                    key: ValueKey('UnknownPage'), child: UnknownPage()),
              if (currentConfiguration.page == GameRoutePage.Settings)
                MaterialPage(
                    key: ValueKey('SettingsPage'), child: SettingsPage()),
              if (currentConfiguration.page == GameRoutePage.About)
                MaterialPage(key: ValueKey('AboutPage'), child: AboutPage()),
              if (currentConfiguration.page == GameRoutePage.WorldSet ||
                  currentConfiguration.page == GameRoutePage.World ||
                  currentConfiguration.page == GameRoutePage.Level)
                MaterialPage(
                    key: ValueKey('WorldSetPage'), child: WorldSetPage()),
              if (currentConfiguration.page == GameRoutePage.World ||
                  currentConfiguration.page == GameRoutePage.Level ||
                  currentConfiguration.source == GameRoutePage.World)
                MaterialPage(
                    key: ValueKey('WorldPage'),
                    child: WorldPage(currentConfiguration.world!)),
              if (currentConfiguration.page == GameRoutePage.Level)
                MaterialPage(
                    key: ValueKey('LevelPage'),
                    child: LevelPage(currentConfiguration.world!,
                        currentConfiguration.level!,
                        key: Key(
                            "${currentConfiguration.world!}_${currentConfiguration.level!}"))),
              if (currentConfiguration.page == GameRoutePage.Pay)
                MaterialPage(key: ValueKey('PayPage'), child: PayPage()),
            ],
      onPopPage: (route, result) {
        if (!route.didPop(result)) {
          return false;
        }

        switch (currentConfiguration.page) {
          case GameRoutePage.Home:
            return false;
          case GameRoutePage.Unknown:
          case GameRoutePage.About:
          case GameRoutePage.WorldSet:
          case GameRoutePage.Settings:
            _routeNavigator.goto(GameRoutePath.home());
            break;
          case GameRoutePage.Pay:
            if (currentConfiguration.source == GameRoutePage.World) {
              _routeNavigator
                  .goto(GameRoutePath.world(currentConfiguration.world!));
            } else {
              _routeNavigator.goto(GameRoutePath.home());
            }
            break;
          case GameRoutePage.World:
            _routeNavigator.goto(GameRoutePath.worldSet());
            break;
          case GameRoutePage.Level:
            _routeNavigator
                .goto(GameRoutePath.world(currentConfiguration.world!));
            break;
        }
        notifyListeners();

        return true;
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
