import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/dailyChallenge.dart';
import 'package:flutter/material.dart';

import 'gameRoutePath.dart';

class GameRouteInformationParser extends RouteInformationParser<GameRoutePath> {
  @override
  Future<GameRoutePath> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;

    String root = "";
    if (uri.pathSegments.length >= 1) {
      root = uri.pathSegments[0];
    }

    switch (root) {
      case "daily":
        if (uri.pathSegments.length == 1) return GameRoutePath.daily();
        if (uri.pathSegments.length == 2 &&
            DailyChallenge.tryParse(uri.pathSegments[1]) != null) {
          return GameRoutePath.dailyLevel(uri.pathSegments[1]);
        }
        return GameRoutePath.unknown();
      case "world":
        if (uri.pathSegments.length != 2 && uri.pathSegments.length != 4) {
          return GameRoutePath.unknown();
        }
        final world = int.tryParse(uri.pathSegments[1]);
        if (world == null || !GameState.worldIds.contains(world)) {
          return GameRoutePath.unknown();
        }
        if (uri.pathSegments.length == 2) {
          return GameRoutePath.world(world);
        }
        final level = int.tryParse(uri.pathSegments[3]);
        if (uri.pathSegments[2] != 'level' ||
            level == null ||
            level < 1 ||
            level > GameState.UnlockedLevelsPerWorld) {
          return GameRoutePath.unknown();
        }
        return GameRoutePath.level(world, level);
      case "worldSet":
        return GameRoutePath.worldSet();
      case "about":
        return GameRoutePath.about();
      case "pay":
        return GameRoutePath.pay();
      case "settings":
        return GameRoutePath.settings();
      default:
        return GameRoutePath.home();
    }
  }

  @override
  RouteInformation? restoreRouteInformation(GameRoutePath path) {
    if (path.page == GameRoutePage.Home) {
      return RouteInformation(uri: Uri.parse('/'));
    }
    if (path.page == GameRoutePage.About) {
      return RouteInformation(uri: Uri.parse('/about'));
    }
    if (path.page == GameRoutePage.Settings) {
      return RouteInformation(uri: Uri.parse('/settings'));
    }
    if (path.page == GameRoutePage.Daily) {
      return RouteInformation(uri: Uri.parse('/daily'));
    }
    if (path.page == GameRoutePage.DailyLevel) {
      return RouteInformation(uri: Uri.parse('/daily/${path.dailyDate}'));
    }
    if (path.page == GameRoutePage.Pay) {
      return RouteInformation(uri: Uri.parse('/pay'));
    }
    if (path.page == GameRoutePage.WorldSet) {
      return RouteInformation(uri: Uri.parse('/worldSet'));
    }
    if (path.page == GameRoutePage.World) {
      return RouteInformation(uri: Uri.parse('/world/${path.world}'));
    }
    if (path.page == GameRoutePage.Level) {
      return RouteInformation(
        uri: Uri.parse('/world/${path.world}/level/${path.level}'),
      );
    }
    return null;
  }
}
