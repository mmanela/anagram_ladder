import 'dart:async';
import 'dart:math';

import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/components/customReorderableDragStartListener.dart';
import 'package:anagram_ladder/components/fixedLetterRow.dart';
import 'package:anagram_ladder/components/hintDialog.dart';
import 'package:anagram_ladder/components/letterBoxDimensions.dart';
import 'package:anagram_ladder/components/winningPopup.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LevelPage extends StatefulWidget {
  static const solveDuration = Duration(milliseconds: 320);
  static const cascadeDelay = Duration(milliseconds: 180);
  final int world;
  final int level;

  LevelPage(this.world, this.level, {super.key});

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  List<LadderLevel> _levels = [];
  List<List<String>> _filledLetters = [];
  int _currentRung = 0;
  bool _wasPlayed = true;
  bool _levelComplete = false;
  bool _showWinningView = false;
  final _activeRowKey = GlobalKey();
  Timer? _completionTimer;
  Timer? _cascadeTimer;
  Duration get _solveDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : LevelPage.solveDuration;
  Duration get _cascadeDelay => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : LevelPage.cascadeDelay;

  bool get isWon => _levels.isNotEmpty && _currentRung >= _levels.length;
  LadderLevel get currentLevel => _levels[_currentRung];
  List<String> get activeLetters => _filledLetters[_currentRung];

  @override
  void initState() {
    super.initState();
    final game = context.read<GameState>();
    game.getLevelOrLoad(widget.world, widget.level).then((ladder) {
      if (!mounted) return;
      final saved = game.getLevelState(widget.world, widget.level);
      setState(() {
        _levels = ladder.getBottomUp();
        if (saved.isEmpty) {
          _initializeLevelNew();
        } else {
          _filledLetters = saved.levelLetters;
          _currentRung = saved.currentRung;
          if (isWon) {
            _wasPlayed = false;
            _showWinningView = true;
          } else {
            _checkActiveRow();
          }
        }
      });
      _scrollToActiveRow();
    });
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _cascadeTimer?.cancel();
    super.dispose();
  }

  void _initializeLevelNew() {
    _filledLetters = [
      for (final rung in _levels) List.filled(rung.letterCount, ''),
    ];
    _filledLetters[0] = List.of(currentLevel.letters)..shuffle();
    for (var attempt = 0; attempt < 10; attempt++) {
      if (!currentLevel.words.contains(activeLetters.join())) break;
      activeLetters.shuffle();
    }
    _checkActiveRow();
  }

  void _resetLevel() {
    _completionTimer?.cancel();
    _cascadeTimer?.cancel();
    setState(() {
      _currentRung = 0;
      _wasPlayed = true;
      _levelComplete = false;
      _showWinningView = false;
      _initializeLevelNew();
    });
    _scrollToActiveRow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${GameState.worldLabels[widget.world]} Ladder #${widget.level}',
        ),
      ),
      body: SafeArea(
        child: _levels.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading ladder',
                ),
              )
            : Stack(
                children: [
                  _board(context),
                  if (_showWinningView)
                    WinningPopup(
                      wasPlayed: _wasPlayed,
                      world: widget.world,
                      level: widget.level,
                      resetLevel: _resetLevel,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _board(BuildContext context) {
    final dimensions = LetterBoxDimensions(
      context,
      widget.world,
      _levels.length,
    );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 732),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isWon
                          ? 'Ladder complete'
                          : 'Rung ${_currentRung + 1} of ${_levels.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: min(_currentRung, _levels.length) / _levels.length,
                      semanticsLabel:
                          'Ladder progress, $_currentRung of '
                          '${_levels.length} rungs solved',
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 24),
                    for (var rung = _levels.length - 1; rung >= 0; rung--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: !isWon && rung == _currentRung
                            ? _activeRow(context, dimensions)
                            : FixedLetterRow(_filledLetters[rung], dimensions),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _activeRow(BuildContext context, LetterBoxDimensions dimensions) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: _activeRowKey,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _levelComplete
                  ? 'Word found!'
                  : '${currentLevel.letterCount} letters, '
                        '${currentLevel.levelWordCount} '
                        '${currentLevel.levelWordCount == 1 ? 'possible word' : 'possible words'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Center(
            child: SizedBox(
              width: activeLetters.length * dimensions.boxWidth,
              height: dimensions.boxHeight,
              child: ReorderableListView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: _moveLetter,
                proxyDecorator: (child, index, animation) => Material(
                  elevation: 6,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
                children: [
                  for (var index = 0; index < activeLetters.length; index++)
                    SizedBox(
                      key: ValueKey(index),
                      width: dimensions.boxWidth,
                      child: CustomReorderableDragStartListener(
                        index: index,
                        draggingEnabled: !_levelComplete,
                        child: AnimatedContainer(
                          duration: _solveDuration,
                          margin: const EdgeInsets.all(3),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _levelComplete
                                ? const Color(0xFF256144)
                                : colors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _levelComplete
                                  ? const Color(0xFF256144)
                                  : colors.outlineVariant,
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                activeLetters[index],
                                textScaler: dimensions.textScaler,
                                style: TextStyle(
                                  fontSize: dimensions.boxFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: _levelComplete
                                      ? Colors.white
                                      : colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  children: [
                    TextButton.icon(
                      onPressed: _levelComplete
                          ? null
                          : () {
                              setState(() => activeLetters.shuffle());
                              _checkActiveRow();
                            },
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Shuffle'),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          HintDialog.show(context, currentLevel.words),
                      icon: const Icon(Icons.lightbulb_outline_rounded),
                      label: const Text('Hint'),
                    ),
                  ],
                ),
                const Text(
                  'Drag the letters to make a word. '
                  'Each solved word adds new letters.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _moveLetter(int oldIndex, int newIndex) {
    if (_levelComplete || oldIndex == newIndex) return;
    _cascadeTimer?.cancel();
    setState(
      () => activeLetters.insert(newIndex, activeLetters.removeAt(oldIndex)),
    );
    _checkActiveRow();
  }

  void _checkActiveRow({bool delayed = false}) {
    if (_levelComplete || isWon) return;
    _persistState();
    if (!currentLevel.words.contains(activeLetters.join())) return;
    if (delayed) {
      _cascadeTimer?.cancel();
      _cascadeTimer = Timer(_cascadeDelay, () {
        if (mounted) _checkActiveRow();
      });
      return;
    }
    setState(() => _levelComplete = true);
    _completionTimer = Timer(_solveDuration, () {
      if (!mounted) return;
      final solved = List<String>.of(activeLetters);
      setState(() {
        _levelComplete = false;
        _currentRung++;
        if (!isWon) {
          _filledLetters[_currentRung] = solved
            ..addAll(currentLevel.lettersToAdd);
        }
      });
      if (isWon) {
        _persistState().then((_) {
          if (mounted) setState(() => _showWinningView = true);
        });
      } else {
        _checkActiveRow(delayed: true);
        _scrollToActiveRow();
      }
    });
  }

  Future<void> _persistState() async {
    await context.read<GameState>().persistLevelState(
      LevelState(
        widget.world,
        widget.level,
        _currentRung == 0 ? 0 : _filledLetters[_currentRung - 1].length,
        _currentRung,
        _levels.length,
        _filledLetters.map((row) => List<String>.of(row)).toList(),
      ),
    );
  }

  void _scrollToActiveRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _activeRowKey.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }
}
