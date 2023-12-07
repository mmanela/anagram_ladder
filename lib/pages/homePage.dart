import 'dart:math';

import 'package:anagram_ladder/components/gameMenuButton.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:anagram_ladder/utils/screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final windowSize = MediaQuery.of(context).size;
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: Padding(
      padding: EdgeInsets.fromLTRB(0, 5, 0, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Hero(
              tag: "logo",
              child: ConstrainedBox(
                  constraints: isPortrait
                      ? BoxConstraints.loose(Size.fromWidth(windowSize.width))
                      : BoxConstraints.loose(Size.fromHeight(150)),
                  child: Image(image: AssetImage("assets/ag_logo_wide.png")))),
          SizedBox(height: 10),
          Expanded(child: _gridView(context))
        ],
      ),
    ))));
  }
}

Widget _gridView(BuildContext context) {
  final textScaleFactor = min(1.4, MediaQuery.of(context).textScaleFactor);
  final nav = context.read<GameRouteNavigator>();
  final isPortrait = shouldTreatAsPortrait(context);
  return GridView.count(
    crossAxisCount: isPortrait ? 1 : 2,
    children: <Widget>[
      Center(
          child: GameMenuButton(
              onPressed: () => nav.goto(GameRoutePath.worldSet()),
              child: Text("Play", textScaleFactor: textScaleFactor))),
      Center(
          child: GameMenuButton(
              onPressed: () => nav.goto(GameRoutePath.about()),
              child: Text("About", textScaleFactor: textScaleFactor))),
      Center(
          child: GameMenuButton(
              onPressed: () => nav.goto(GameRoutePath.settings()),
              child: Text("Settings", textScaleFactor: textScaleFactor))),
      if (defaultTargetPlatform != TargetPlatform.android)
        Center(
            child: GameMenuButton(
                onPressed: () => nav.goto(GameRoutePath.pay()),
                child: Text("Store", textScaleFactor: textScaleFactor))),
    ],
    childAspectRatio: isBigScreen(context) ? 3 : 4,
    padding: EdgeInsets.zero,
  );
}
