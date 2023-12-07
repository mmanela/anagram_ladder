import 'package:anagram_ladder/models/gameState.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoadingPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();

    final gameState = context.read<GameState>();
    // Pre-load the world
    gameState.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: Hero(
                tag: "logo",
                child: Image(
                    height: 375,
                    width: 375,
                    image: AssetImage(
                      "assets/ag_logo_simple.png",
                    )))));
  }
}
