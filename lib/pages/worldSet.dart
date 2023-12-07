import 'dart:math';

import 'package:anagram_ladder/components/gameMenuButton.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:anagram_ladder/utils/screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorldSetPage extends StatelessWidget {
  WorldSetPage();

  Widget _worldButton(BuildContext context, int worldNum) {
    final nav = context.read<GameRouteNavigator>();
    final gameState = context.read<GameState>();
    final label = GameState.worldLabels[worldNum];
    final info = gameState.getWorldCompletionInfo(worldNum);
    final textScaleFactor = min(1.3, MediaQuery.of(context).textScaleFactor);
    return Center(
        child: Container(
            padding: EdgeInsets.only(bottom: 0, top: 5),
            child: GameMenuButton(
                onPressed: () => nav.goto(GameRoutePath.world(worldNum)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                          child:
                              Text("$label", textScaleFactor: textScaleFactor)),
                      Text("${info.completedCount} / ${info.levelCount}",
                          textScaleFactor: textScaleFactor,
                          style: Theme.of(context).primaryTextTheme.titleMedium)
                    ]))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Pick your difficulty")),
        body: SafeArea(
            child: Center(
          child: _gridView(context),
        )));
  }

  Widget _gridView(BuildContext context) {
    final isPortrait = shouldTreatAsPortrait(context);
    final buttons =
        GameState.worldIds.map((e) => _worldButton(context, e)).toList();
    return GridView.count(
      crossAxisCount: isPortrait ? 1 : 2,
      children: buttons,
      childAspectRatio: isBigScreen(context) ? 3 : 4,
      padding: EdgeInsets.zero,
    );
  }
}
