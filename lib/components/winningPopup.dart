import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:anagram_ladder/utils/screen.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WinningPopup extends StatefulWidget {
  final Function resetLevel;
  final bool wasPlayed;
  final int world;
  final int level;
  WinningPopup({
    Key? key,
    required this.wasPlayed,
    required this.world,
    required this.level,
    required this.resetLevel,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _WinningPopupState();
}

class _WinningPopupState extends State<WinningPopup> {
  late ConfettiController _controllerCenter;
  _WinningPopupState();

  @override
  void initState() {
    super.initState();
    _controllerCenter = ConfettiController(
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    _controllerCenter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _winningDialogContents(context);
  }

  Widget _winningDialogContents(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          Center(child: _dialogBody(context)),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _controllerCenter,
              emissionFrequency: 0.02,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: true,
            ),
          ),
        ],
      ),
    );
  }

  Card _dialogBody(BuildContext context) {
    final bigScreen = isBigScreen(context);
    final gameState = context.read<GameState>();
    final nextLevel = gameState.getNextUnfinishedLevel(
      widget.world,
      widget.level,
    );
    bool hasNextLevel = nextLevel != null;
    bool isWorldDone = gameState.isWorldDone(widget.world);
    bool isGameDone = gameState.isGameDone();
    final nav = context.read<GameRouteNavigator>();

    final textScaler = MediaQuery.textScalerOf(context);
    final double size = bigScreen ? 22 : 18;
    var label = "Level Complete!";
    if (widget.wasPlayed) {
      if (isGameDone) {
        label = "You beat the game!";
        _controllerCenter.play();
      } else if (isWorldDone) {
        final worldName = GameState.worldLabels[widget.world];
        label = "$worldName difficulty complete!";
        _controllerCenter.play();
      }
    }
    return Card(
      child: Container(
        width: bigScreen ? 425 : 325,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: const Color(0xFF256144),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                textScaler: textScaler,
                style: TextStyle(
                  fontSize: 34,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              if (hasNextLevel)
                FilledButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    textStyle: TextStyle(fontSize: size),
                  ),
                  onPressed: () {
                    nav.goto(nextLevel);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.skip_next, size: size),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text("Next Level", textScaler: textScaler),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: TextStyle(fontSize: size),
                    ),
                    onPressed: () {
                      widget.resetLevel();
                    },
                    icon: Icon(Icons.refresh, size: size),
                    label: Text("Restart", textScaler: textScaler),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(right: 5),
                      textStyle: TextStyle(fontSize: size),
                    ),
                    onPressed: () {
                      nav.goto(GameRoutePath.world(widget.world));
                    },
                    icon: const Icon(Icons.dashboard),
                    label: Text("Level Screen", textScaler: textScaler),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
