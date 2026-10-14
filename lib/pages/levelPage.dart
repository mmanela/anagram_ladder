import 'dart:async';
import 'dart:math';

import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/components/customReorderableDragStartListener.dart';
import 'package:anagram_ladder/components/fixedLetterRow.dart';
import 'package:anagram_ladder/components/hintPanel.dart';
import 'package:anagram_ladder/components/letterBoxDimensions.dart';
import 'package:anagram_ladder/components/winningPopup.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
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
  static final _moveLeftAction = CustomSemanticsAction(label: 'Move left');
  static final _moveRightAction = CustomSemanticsAction(label: 'Move right');
  List<LadderLevel> _levels = [];
  List<List<String>> _filledLetters = [];
  int _currentRung = 0;
  int? _selectedLetter;
  bool _showHints = false;
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
      _selectedLetter = null;
      _showHints = false;
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
                        child: _letterTile(context, index, dimensions),
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
                              setState(() {
                                _selectedLetter = null;
                                activeLetters.shuffle();
                              });
                              _checkActiveRow();
                            },
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Shuffle'),
                    ),
                    TextButton.icon(
                      onPressed: _levelComplete
                          ? null
                          : () {
                              setState(() => _showHints = !_showHints);
                              if (_showHints) _scrollToActiveRow();
                            },
                      icon: const Icon(Icons.lightbulb_outline_rounded),
                      label: Text(_showHints ? 'Hide hint' : 'Hint'),
                    ),
                  ],
                ),
                Visibility(
                  visible: _showHints,
                  maintainState: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: HintPanel(
                      key: ValueKey(_currentRung),
                      words: currentLevel.words,
                    ),
                  ),
                ),
                if (!_showHints)
                  Text(
                    _selectedLetter == null
                        ? 'Drag to reorder, or tap a letter then its new position. '
                              'Each solved word adds new letters.'
                        : 'Tap another position to move this letter there.',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _letterTile(
    BuildContext context,
    int index,
    LetterBoxDimensions dimensions,
  ) {
    final colors = Theme.of(context).colorScheme;
    final selected = index == _selectedLetter;
    void select() {
      if (_levelComplete) return;
      if (_selectedLetter != null && !selected) {
        _moveLetter(_selectedLetter!, index);
      } else {
        setState(() => _selectedLetter = selected ? null : index);
        if (context.read<GameState>().hapticsEnabled)
          HapticFeedback.selectionClick();
      }
    }

    return Semantics(
      key: ValueKey('letter-$index'),
      button: !_levelComplete,
      selected: selected,
      label:
          'Letter ${activeLetters[index]}, '
          'position ${index + 1} of ${activeLetters.length}',
      hint: 'Select a letter, then its new position, or use the move actions.',
      onTap: _levelComplete ? null : select,
      customSemanticsActions: _levelComplete
          ? null
          : {
              if (index > 0)
                _moveLeftAction: () => _moveLetter(index, index - 1),
              if (index < activeLetters.length - 1)
                _moveRightAction: () => _moveLetter(index, index + 1),
            },
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _levelComplete ? null : select,
          child: AnimatedContainer(
            duration: _solveDuration,
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _levelComplete
                  ? const Color(0xFF256144)
                  : selected
                  ? colors.primaryContainer
                  : colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _levelComplete
                    ? const Color(0xFF256144)
                    : selected
                    ? colors.primary
                    : colors.outlineVariant,
                width: selected ? 2 : 1,
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
                    color: _levelComplete ? Colors.white : colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _moveLetter(int oldIndex, int newIndex) {
    if (_levelComplete || oldIndex == newIndex) return;
    _cascadeTimer?.cancel();
    setState(() {
      _selectedLetter = null;
      activeLetters.insert(newIndex, activeLetters.removeAt(oldIndex));
    });
    if (!currentLevel.words.contains(activeLetters.join()) &&
        context.read<GameState>().hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
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
    if (context.read<GameState>().hapticsEnabled) HapticFeedback.lightImpact();
    _completionTimer = Timer(_solveDuration, () {
      if (!mounted) return;
      final solved = List<String>.of(activeLetters);
      setState(() {
        _levelComplete = false;
        _selectedLetter = null;
        _showHints = false;
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
