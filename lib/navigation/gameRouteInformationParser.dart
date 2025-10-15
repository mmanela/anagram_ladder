import 'package:flutter/material.dart';

import 'gameRoutePath.dart';

class GameRouteInformationParser extends RouteInformationParser<GameRoutePath> {
  @override
  Future<GameRoutePath> parseRouteInformation(
      RouteInformation routeInformation) async {
    final uri = routeInformation.uri;

    String root = "";
    if (uri.pathSegments.length >= 1) {
      root = uri.pathSegments[0];
    }

    switch (root) {
      case "world":
        int? world;
        int? level;
        if (uri.pathSegments.length >= 2) {
          world = int.tryParse(uri.pathSegments[1]);
        }
        if (uri.pathSegments.length >= 4 && uri.pathSegments[2] == 'level') {
          level = int.tryParse(uri.pathSegments[3]);
        }
        if (level != null && world != null) {
          return GameRoutePath.level(world, level);
        } else if (world != null) {
          return GameRoutePath.world(world);
        }
        return GameRoutePath.unknown();
      case "worldSet":
        return GameRoutePath.worldSet();
      case "about":
        return GameRoutePath.about();
      case "pay":
        return GameRoutePath.pay();
      case "settings":
        return GameRoutePath.pay();
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
          uri: Uri.parse('/world/${path.world}/level/${path.level}'));
    }
    return null;
  }
}
