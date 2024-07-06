import 'dart:async';
import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/components/FixedLetterRow.dart';
import 'package:anagram_ladder/components/customReorderableDragStartListener.dart';
import 'package:anagram_ladder/components/hintDialog.dart';
import 'package:anagram_ladder/components/letterBoxDimensions.dart';
import 'package:anagram_ladder/components/winningPopup.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:anagram_ladder/utils/screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:more/collection.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class LevelPage extends StatefulWidget {
  final int world;
  final int level;

  LevelPage(this.world, this.level, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  bool isLoading = true;
  LadderLevel? rootLevel;
  List<LadderLevel> _levels = List.empty();
  late List<List<String>> _filledLetters;
  int _currentRung = 0;
  late int _maxRung;
  bool _isSaving = true; // Indicates if the user just played this level
  // versus it having already been won
  bool _wasPlayed = true;
  bool _levelComplete = false;
  final int _levelCompleteAnimationDuration = 1000;
  final int _levelCompleteCascadeDelay = 500;

  bool _showWinningView = false;
  bool get isWon => _currentRung > _maxRung;
  LadderLevel get currentLevel => _levels[_currentRung];
  List<String> get activeLetters => _filledLetters[_currentRung];
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();

    final gameState = context.read<GameState>();
    final levelState = gameState.getLevelState(widget.world, widget.level);
    gameState.getLevelOrLoad(widget.world, widget.level).then((value) {
      setState(() {
        rootLevel = value;
        _levels = value.getBottomUp();
        _maxRung = _levels.length - 1;

        if (levelState.isEmpty) {
          _initializeLevelNew();
        } else {
          _initializeLevelFromState(levelState);
        }

        isLoading = false;
      });
    });
  }

  void _initializeLevelFromState(LevelState levelState) {
    _filledLetters = levelState.levelLetters;
    _currentRung = levelState.currentRung;

    if (isWon) {
      _wasPlayed = false;
      _handleWinning();
    } else {
      _checkActiveRow(context);
    }
  }

  void _initializeLevelNew() {
    _filledLetters = List.generate(
        _levels.length, (index) => List.filled(_levels[index].letterCount, ""));
    _filledLetters[_currentRung] = currentLevel.letters.toList()..shuffle();

    //Shuffle and try to ensure we dont start with a filled word
    for (int i = 0; i < 10; i++) {
      _filledLetters[_currentRung].shuffle();
      var word = _filledLetters[_currentRung].join();
      if (!currentLevel.words.contains(word)) {
        break;
      }
    }

    _checkActiveRow(context);
  }

  void _resetLevel() {
    _currentRung = 0;
    _wasPlayed = true;
    _showWinningView = false;
    _initializeLevelNew();
  }

  @override
  Widget build(BuildContext context) {
    //print("Level Page Build called");
    final label = GameState.worldLabels[widget.world];
    return Scaffold(
        appBar: AppBar(title: Text("$label Ladder #${widget.level}")),
        body: SafeArea(
            child: Container(
                padding: const EdgeInsets.only(top: 10, left: 10),
                child: isLoading
                    ? const CircularProgressIndicator(
                        semanticsLabel: "Loading...",
                      )
                    : _renderMainStack(context))));
  }

  Widget _renderMainStack(BuildContext context) {
    return Stack(children: [
      _renderTree(context),
      if (_showWinningView) _winningView(context)
    ]);
  }

  Widget _winningView(BuildContext context) {
    return WinningPopup(
      wasPlayed: _wasPlayed,
      world: widget.world,
      level: widget.level,
      resetLevel: _resetLevel,
    );
  }

  Widget _renderTree(BuildContext context) {
    final dimensions =
        LetterBoxDimensions(context, widget.world, _levels.length);
    List<Widget> futureRows = isWon
        ? List.empty()
        : IntegerRange(_levels.length - 1, _currentRung)
            .map((e) => FixedLetterRow(_filledLetters[e], dimensions))
            .toList();
    List<Widget> pastRows = IntegerRange(_currentRung - 1, -1)
        .map((e) => FixedLetterRow(_filledLetters[e], dimensions))
        .toList();
    Widget activeRow = isWon
        ? Container()
        : _activeLetterRow(context, _currentRung, dimensions);

    final rows = [...futureRows, activeRow, ...pastRows];
    return ScrollablePositionedList.builder(
        itemCount: rows.length,
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        initialScrollIndex: !isWon ? _maxRung - _currentRung : 0,
        itemBuilder: (context, index) => rows[index]);
  }

  List<Widget> _letterBoxes(BuildContext context, List<String> letters,
      int rung, LetterBoxDimensions dimensions) {
    List<Widget> boxes = List.empty(growable: true);
    for (int index = 0; index < letters.length; index++) {
      final box = Container(
          key: Key("$index"),
          width: dimensions.boxWidth,
          child: CustomReorderableDragStartListener(
              index: index,
              draggingEnabled: !_levelComplete,
              child: Container(
                  child: Card(
                      margin: EdgeInsets.all(4),
                      elevation: 2,
                      shadowColor: Colors.white,
                      child: AnimatedContainer(
                          curve: Curves.easeInOut,
                          duration: Duration(
                              milliseconds: _levelCompleteAnimationDuration),
                          color: _levelComplete ? Colors.green : Colors.white70,
                          child: Center(
                              child: Text(
                            letters[index],
                            textScaler:
                                TextScaler.linear(dimensions.textScaleFactor),
                            style: TextStyle(
                                fontSize: dimensions.boxFontSize,
                                color: _levelComplete
                                    ? Colors.white
                                    : Colors.black),
                          )))))));

      boxes.add(box);
    }

    return boxes;
  }

  Widget _activeLetterRow(
      BuildContext context, int rung, LetterBoxDimensions dimensions) {
    final letterBoxes = _letterBoxes(context, activeLetters, rung, dimensions);

    final bigScreen = isBigScreen(context);
    final padding = bigScreen ? 15.0 : 10.0;
    final double activeInfoHeight = bigScreen ? 40 : 30;
    return Container(
        height: dimensions.boxHeight + activeInfoHeight,
        margin: EdgeInsets.only(bottom: padding, top: padding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
              child: ReorderableListView(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    if (_levelComplete) {
                      return;
                    }
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final String item = activeLetters.removeAt(oldIndex);
                      activeLetters.insert(newIndex, item);
                    });

                    _checkActiveRow(context, dimensions);
                  },
                  children: letterBoxes)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: isWon
                  ? Container()
                  : _activeRowInfo(context, activeInfoHeight, dimensions))
        ]));
  }

  Widget _activeRowInfo(
      BuildContext context, double height, LetterBoxDimensions dimensions) {
    final wordCount = currentLevel.levelWordCount;

    final bigScreen = isBigScreen(context);
    final double fontSize = bigScreen ? 20 : 16;
    return SizedBox(
        height: height,
        child: Padding(
            padding: const EdgeInsets.only(right: 15, left: 5, top: 5),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                      wordCount == 1
                          ? "$wordCount possibility"
                          : "$wordCount possibilites",
                      style: TextStyle(
                          fontSize: fontSize, color: Colors.grey[600]),
                      textScaleFactor: dimensions.textScaleFactor),
                  TextButton.icon(
                      icon: Icon(
                        Icons.shuffle,
                        size: fontSize,
                      ),
                      label: Text("Shuffle",
                          textScaleFactor: dimensions.textScaleFactor),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          textStyle: TextStyle(fontSize: fontSize)),
                      onPressed: () {
                        setState(() {
                          // If complete already don't shuffle
                          if (_levelComplete) {
                            return;
                          }
                          activeLetters.shuffle();
                          _checkActiveRow(context);
                        });
                      }),
                  TextButton.icon(
                      icon: Icon(
                        Icons.help_outline,
                        size: fontSize,
                      ),
                      label: Text("Hint",
                          textScaleFactor: dimensions.textScaleFactor),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          textStyle: TextStyle(fontSize: fontSize)),
                      onPressed: () {
                        HintDialog.show(context, currentLevel.words);
                      })
                ])));
  }

  void _markLevelComplete(BuildContext context,
      [LetterBoxDimensions? dimensions]) {
    setState(() {
      _levelComplete = true;
    });

    if (_currentRung >= _maxRung) {
      Timer(Duration(milliseconds: _levelCompleteAnimationDuration), () {
        _levelComplete = false;
        _currentRung++;
        _persistState(_currentRung).then((_) {
          _handleWinning();
        });
      });
    } else {
      // Finished row, advance to next one
      Timer(Duration(milliseconds: _levelCompleteAnimationDuration), () {
        final lastLetters = activeLetters.toList();

        setState(() {
          _levelComplete = false;
          _currentRung++;
          _filledLetters[_currentRung] = lastLetters
            ..addAll(currentLevel.lettersToAdd);
        });

        // Only scroll if we think the size is larger than screen size
        if (dimensions != null && dimensions.scrollNeeded) {
          int nextIndex = _maxRung - _currentRung;

          // Check if the next item is not already visible or is partially visible
          bool rowFullyVisible = false;
          final item = _itemPositionsListener.itemPositions.value
              .where((element) => element.index == nextIndex)
              .toList();
          if (item.length == 1) {
            ItemPosition visibleItem = item[0];
            rowFullyVisible = visibleItem.itemLeadingEdge >= 0 &&
                visibleItem.itemTrailingEdge <= 1;
          }

          // Only scroll if not fully visible
          if (!rowFullyVisible) {
            Timer(Duration(milliseconds: 250), () {
              _itemScrollController.scrollTo(
                  index: nextIndex, duration: Duration(milliseconds: 250));
            });
          }
        }
        // Persist state for next run (even though we are still animating
        // this one)
        _persistState(_currentRung);

        // Check if adding letters forced the row to autowin!
        _checkActiveRow(context, dimensions, true);
      });
    }
  }

  void _checkActiveRow(BuildContext context,
      [LetterBoxDimensions? dimensions, bool delayed = false]) {
    final currentWord = activeLetters.join();
    final validWords = currentLevel.words;
    bool isValid = validWords.any((element) => element == currentWord);
    if (isValid) {
      if (delayed) {
        Timer(Duration(milliseconds: _levelCompleteCascadeDelay), () {
          _markLevelComplete(context, dimensions);
        });
      } else {
        _markLevelComplete(context, dimensions);
      }
    } else {
      _persistState(_currentRung);
    }
  }

  Future _persistState(int currentRung) async {
    final state = context.read<GameState>();
    int maxWordLength =
        _currentRung <= 0 ? 0 : _filledLetters[currentRung - 1].length;
    final levelState = LevelState(widget.world, widget.level, maxWordLength,
        _currentRung, _maxRung + 1, _filledLetters);

    // diable backbutton until saving is done
    setState(() {
      _isSaving = false;
    });
    await state.persistLevelState(levelState);
    setState(() {
      _isSaving = true;
    });
  }

  void _handleWinning() {
    _showWinningView = true;
  }
}
