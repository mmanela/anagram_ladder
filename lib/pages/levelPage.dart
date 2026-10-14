import 'dart:async';
import 'dart:math';

import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/components/customReorderableDragStartListener.dart';
import 'package:anagram_ladder/components/fixedLetterRow.dart';
import 'package:anagram_ladder/components/hintDialog.dart';
import 'package:anagram_ladder/components/letterBoxDimensions.dart';
import 'package:anagram_ladder/components/winningPopup.dart';
import 'package:anagram_ladder/components/dailyResultCard.dart';
import 'package:anagram_ladder/models/dailyChallenge.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class LevelPage extends StatefulWidget {
  static const solveDuration = Duration(milliseconds: 320);
  static const cascadeDelay = Duration(milliseconds: 180);
  static const newLetterDuration = Duration(milliseconds: 700);
  final int world;
  final int level;
  final DailyChallenge? daily;

  LevelPage(this.world, this.level, {super.key}) : daily = null;

  LevelPage.daily(DailyChallenge challenge, {super.key})
    : daily = challenge,
      world = DailyChallenge.world,
      level = challenge.level;

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
  Set<int> _newLetterIndices = {};
  bool _wasPlayed = true;
  bool _levelComplete = false;
  bool _showWinningView = false;
  bool _showInstructions = true;
  Object? _loadError;
  final _activeLettersKey = GlobalKey();
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
    _showInstructions = !game.controlsLearned;
    _loadLevel();
  }

  Future<void> _loadLevel() async {
    final game = context.read<GameState>();
    try {
      final ladder = await game.getLevelOrLoad(widget.world, widget.level);
      if (!mounted) return;
      final saved = widget.daily == null
          ? game.getLevelState(widget.world, widget.level)
          : game.getDailyState(widget.daily!);
      final levels = ladder.getBottomUp();
      if (widget.daily != null && !saved.isEmpty) {
        if (saved.rungCount != levels.length ||
            List.generate(levels.length, (index) => index).any(
              (index) =>
                  saved.levelLetters[index].length !=
                      levels[index].letterCount ||
                  (index < saved.currentRung &&
                      !levels[index].words.contains(
                        saved.levelLetters[index].join(),
                      )),
            )) {
          throw const FormatException(
            'Daily progress does not match the ladder',
          );
        }
        if (!saved.isWon) {
          final actual = List.of(saved.levelLetters[saved.currentRung])..sort();
          final expected = List.of(levels[saved.currentRung].letters)..sort();
          if (actual.join() != expected.join()) {
            throw const FormatException('Daily letters do not match the rung');
          }
        } else if (!game.isDailyCompleted(widget.daily!)) {
          await game.persistDailyState(widget.daily!, saved);
          if (!mounted) return;
        }
      }
      setState(() {
        _levels = levels;
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
    } catch (error) {
      debugPrint('Ladder: could not load: $error');
      if (mounted) setState(() => _loadError = error);
    }
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
    final random = widget.daily == null
        ? null
        : Random(widget.daily!.dayNumber);
    _filledLetters[0] = List.of(currentLevel.letters)..shuffle(random);
    for (var attempt = 0; attempt < 10; attempt++) {
      if (!currentLevel.words.contains(activeLetters.join())) break;
      activeLetters.shuffle(random);
    }
    _checkActiveRow();
  }

  void _resetLevel() {
    _completionTimer?.cancel();
    _cascadeTimer?.cancel();
    setState(() {
      _currentRung = 0;
      _selectedLetter = null;
      _newLetterIndices = {};
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
          widget.daily == null
              ? '${GameState.worldLabels[widget.world]} Ladder #${widget.level}'
              : 'Daily ${widget.daily!.dateKey}',
        ),
        actions: [
          IconButton(
            tooltip: 'How to play',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showDialog<void>(
              context: context,
              useRootNavigator: false,
              builder: (context) => AlertDialog(
                scrollable: true,
                title: const Text('How to play'),
                content: const Text(
                  'Drag letters horizontally, or tap a letter and then its '
                  'new position.\n\nEach solved word adds new letters. '
                  'Rearrange them to climb the next rung.\n\n'
                  'Hint shows the first and last letters of one possible word. '
                  'There is no timer or penalty for using hints.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loadError != null
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not load this ladder. Please try again.',
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _loadError = null);
                          _loadLevel();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : _levels.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading ladder',
                ),
              )
            : Stack(
                children: [
                  _board(context),
                  if (_showWinningView && widget.daily != null)
                    Center(
                      child: DailyResultCard(
                        challenge: widget.daily!,
                        wordLengths: _levels
                            .map((rung) => rung.letterCount)
                            .toList(),
                        onReplay: _resetLevel,
                        onBack: () => context.read<GameRouteNavigator>().goto(
                          GameRoutePath.daily(),
                        ),
                      ),
                    )
                  else if (_showWinningView)
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final dimensions = LetterBoxDimensions(
          context,
          widget.world,
          _levels.length,
          availableWidth:
              constraints.maxWidth - LetterBoxDimensions.horizontalPadding * 2,
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth:
                      LetterBoxDimensions.MaxBoardWidth +
                      LetterBoxDimensions.horizontalPadding * 2,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LetterBoxDimensions.horizontalPadding,
                    vertical: 16,
                  ),
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
                        value:
                            min(_currentRung, _levels.length) / _levels.length,
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
                              ? _activeRow(context)
                              : FixedLetterRow(
                                  _filledLetters[rung],
                                  dimensions,
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _activeRow(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dimensions = LetterBoxDimensions(
            context,
            activeLetters.length,
            _levels.length,
            availableWidth: constraints.maxWidth,
          );
          return Column(
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
                  key: _activeLettersKey,
                  width: activeLetters.length * dimensions.boxWidth,
                  height: max(64, dimensions.boxHeight),
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
                                    _newLetterIndices = {};
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
                              : () => HintDialog.show(
                                  context,
                                  currentLevel.words,
                                ),
                          icon: const Icon(Icons.lightbulb_outline_rounded),
                          label: const Text('Hint'),
                        ),
                      ],
                    ),
                    if (_showInstructions || _selectedLetter != null)
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
          );
        },
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
        setState(() {
          _selectedLetter = selected ? null : index;
          _newLetterIndices = {};
        });
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
          child: TweenAnimationBuilder<double>(
            key: ValueKey(
              'new-letter-$_currentRung-$index-'
              '${_newLetterIndices.contains(index)}',
            ),
            tween: Tween(
              begin:
                  _newLetterIndices.contains(index) &&
                      !MediaQuery.disableAnimationsOf(context)
                  ? 1.0
                  : 0.0,
              end: 0.0,
            ),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : LevelPage.newLetterDuration,
            builder: (context, highlight, child) => AnimatedContainer(
              duration: _solveDuration,
              margin: const EdgeInsets.all(1),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _levelComplete
                    ? const Color(0xFF256144)
                    : selected
                    ? colors.primaryContainer
                    : Color.lerp(
                        colors.surfaceContainerLowest,
                        colors.primaryContainer,
                        highlight,
                      ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _levelComplete
                      ? const Color(0xFF256144)
                      : selected
                      ? colors.primary
                      : Color.lerp(
                          colors.outlineVariant,
                          colors.primary,
                          highlight,
                        )!,
                  width: selected ? 2 : 1 + highlight,
                ),
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
      _newLetterIndices = {};
      _showInstructions = false;
      activeLetters.insert(newIndex, activeLetters.removeAt(oldIndex));
    });
    unawaited(
      context.read<GameState>().markControlsLearned().catchError((
        Object error,
      ) {
        debugPrint('Controls: could not save the learned preference: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save your controls preference.'),
            ),
          );
        }
      }),
    );
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
        _currentRung++;
        if (!isWon) {
          _newLetterIndices = {
            for (
              var index = solved.length;
              index < solved.length + currentLevel.lettersToAdd.length;
              index++
            )
              index,
          };
          _filledLetters[_currentRung] = solved
            ..addAll(currentLevel.lettersToAdd);
        }
      });
      if (isWon) {
        _persistState().then((saved) {
          if (saved && mounted) setState(() => _showWinningView = true);
        });
      } else {
        _checkActiveRow(delayed: true);
        _scrollToActiveRow();
      }
    });
  }

  Future<bool> _persistState() async {
    final game = context.read<GameState>();
    final progress = LevelState(
      widget.world,
      widget.level,
      _currentRung == 0 ? 0 : _filledLetters[_currentRung - 1].length,
      _currentRung,
      _levels.length,
      _filledLetters.map((row) => List<String>.of(row)).toList(),
    );
    try {
      if (widget.daily == null) {
        await game.persistLevelState(progress);
      } else {
        await game.persistDailyState(widget.daily!, progress);
      }
      return true;
    } catch (error) {
      debugPrint('Ladder: could not save progress: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not save your progress. Please retry.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () async {
                if (await _persistState() && mounted && isWon) {
                  setState(() => _showWinningView = true);
                }
              },
            ),
          ),
        );
      }
      return false;
    }
  }

  void _scrollToActiveRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _activeLettersKey.currentContext;
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
