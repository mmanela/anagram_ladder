import 'dart:async';
import 'dart:math';

import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/components/customReorderableDragStartListener.dart';
import 'package:anagram_ladder/components/fixedLetterRow.dart';
import 'package:anagram_ladder/components/hintDialog.dart';
import 'package:anagram_ladder/components/letterBoxDimensions.dart';
import 'package:anagram_ladder/components/rungTransition.dart';
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
  static const solveDuration = Duration(milliseconds: 380);
  static const finishDuration = Duration(milliseconds: 600);
  static const cascadeDelay = Duration(milliseconds: 240);
  final int world;
  final int level;
  final DailyChallenge? daily;

  LevelPage(this.world, this.level, {super.key}) : daily = null;

  LevelPage.daily(DailyChallenge challenge, {super.key})
    : daily = challenge,
      world = challenge.world,
      level = challenge.level;

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage>
    with SingleTickerProviderStateMixin {
  static final _moveLeftAction = CustomSemanticsAction(label: 'Move left');
  static final _moveRightAction = CustomSemanticsAction(label: 'Move right');
  List<LadderLevel> _levels = [];
  List<List<String>> _filledLetters = [];
  int _currentRung = 0;
  int? _selectedLetter;
  bool _wasPlayed = true;
  bool _levelComplete = false;
  bool _showWinningView = false;
  bool _showInstructions = true;
  Object? _loadError;
  final _activeLettersKey = GlobalKey();
  final _boardLayerKey = GlobalKey();
  final _letterFocusNodes = <int, FocusNode>{};
  late final AnimationController _rungController;
  Rect? _flightFrom;
  Rect? _flightTo;
  int _existingLetterCount = 0;
  Size? _viewportSize;
  Timer? _completionTimer;
  Timer? _cascadeTimer;
  Duration get _solveDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : _levelComplete && _currentRung == _levels.length - 1
      ? LevelPage.finishDuration
      : LevelPage.solveDuration;
  Duration get _cascadeDelay => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : LevelPage.cascadeDelay;

  bool get isWon => _levels.isNotEmpty && _currentRung >= _levels.length;
  bool get _rungInFlight => _flightFrom != null;
  LadderLevel get currentLevel => _levels[_currentRung];
  List<String> get activeLetters => _filledLetters[_currentRung];

  @override
  void initState() {
    super.initState();
    _rungController =
        AnimationController(vsync: this, duration: RungTransition.duration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _finishRungTransition();
          });
    final game = context.read<GameState>();
    _showInstructions = !game.controlsLearned;
    _loadLevel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (_rungInFlight &&
        (MediaQuery.disableAnimationsOf(context) || _viewportSize != size)) {
      _rungController.value = 1;
    }
    _viewportSize = size;
  }

  Future<void> _loadLevel() async {
    final game = context.read<GameState>();
    try {
      final ladder = widget.daily == null
          ? await game.getLevelOrLoad(widget.world, widget.level)
          : await game.getDailyLadder(widget.daily!);
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
    _rungController.dispose();
    for (final node in _letterFocusNodes.values) {
      node.dispose();
    }
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
    _rungController.reset();
    setState(() {
      _currentRung = 0;
      _selectedLetter = null;
      _flightFrom = null;
      _flightTo = null;
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
                  'new position.\n\nWith a keyboard, Tab to a letter and use '
                  'Left or Right to move it. Enter or Space selects a letter; '
                  'Escape clears the selection.\n\nEach solved word adds new letters. '
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
                          GameRoutePath.home(),
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
          physics: _rungInFlight ? const NeverScrollableScrollPhysics() : null,
          child: Stack(
            key: _boardLayerKey,
            children: [
              ConstrainedBox(
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
                                min(_currentRung, _levels.length) /
                                _levels.length,
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
              if (_rungInFlight)
                Positioned.fill(
                  child: RungTransition(
                    animation: _rungController,
                    from: _flightFrom!,
                    to: _flightTo ?? _flightFrom!,
                    letters: activeLetters,
                    existingCount: _existingLetterCount,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _activeRow(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
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
              IgnorePointer(
                ignoring: _rungInFlight,
                child: Opacity(
                  opacity: _rungInFlight ? 0 : 1,
                  child: Center(
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
                          for (
                            var index = 0;
                            index < activeLetters.length;
                            index++
                          )
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
                          onPressed: _levelComplete || _rungInFlight
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
                          onPressed: _levelComplete || _rungInFlight
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
                                  '${Theme.of(context).platform == TargetPlatform.macOS ? ' Tab to a letter, then use Left or Right to move it.' : ''}'
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
    final busy = _levelComplete || _rungInFlight;
    final focusNode = _letterFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'Letter $index'),
    );
    void select() {
      if (busy) return;
      if (_selectedLetter != null && !selected) {
        _moveLetter(_selectedLetter!, index);
      } else {
        setState(() {
          _selectedLetter = selected ? null : index;
        });
        if (context.read<GameState>().hapticsEnabled)
          HapticFeedback.selectionClick();
      }
    }

    return Semantics(
      key: ValueKey('letter-$index'),
      button: !busy,
      selected: selected,
      focusable: !busy,
      focused: focusNode.hasFocus,
      label:
          'Letter ${activeLetters[index]}, '
          'position ${index + 1} of ${activeLetters.length}',
      hint: 'Select a letter, then its new position, or use the move actions.',
      onTap: busy ? null : select,
      customSemanticsActions: busy
          ? null
          : {
              if (index > 0)
                _moveLeftAction: () => _moveLetter(index, index - 1),
              if (index < activeLetters.length - 1)
                _moveRightAction: () => _moveLetter(index, index + 1),
            },
      child: Focus(
        focusNode: focusNode,
        canRequestFocus: !busy,
        includeSemantics: false,
        onFocusChange: (_) => setState(() {}),
        onKeyEvent: (_, event) {
          if (busy ||
              (event is! KeyDownEvent && event is! KeyRepeatEvent) ||
              HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed ||
              HardwareKeyboard.instance.isAltPressed) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight) {
            final destination =
                index + (key == LogicalKeyboardKey.arrowLeft ? -1 : 1);
            if (destination >= 0 && destination < activeLetters.length) {
              _moveLetter(index, destination);
              _letterFocusNodes[destination]?.requestFocus();
            }
            return KeyEventResult.handled;
          }
          if (event is KeyRepeatEvent) return KeyEventResult.ignored;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space) {
            select();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.escape && _selectedLetter != null) {
            setState(() => _selectedLetter = null);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ExcludeSemantics(
          child: MouseRegion(
            cursor: busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : select,
              child: AnimatedContainer(
                duration: _solveDuration,
                margin: const EdgeInsets.all(1),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _levelComplete
                      ? const Color(0xFF256144)
                      : selected || focusNode.hasFocus
                      ? colors.primaryContainer
                      : colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _levelComplete
                        ? const Color(0xFF256144)
                        : selected || focusNode.hasFocus
                        ? colors.primary
                        : colors.outlineVariant,
                    width: selected || focusNode.hasFocus ? 2 : 1,
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
        ),
      ),
    );
  }

  void _moveLetter(int oldIndex, int newIndex) {
    if (_levelComplete || _rungInFlight || oldIndex == newIndex) return;
    _cascadeTimer?.cancel();
    setState(() {
      _selectedLetter = null;
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
    if (_levelComplete || _rungInFlight || isWon) return;
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
      final from =
          !MediaQuery.disableAnimationsOf(context) &&
              _currentRung + 1 < _levels.length
          ? _activeLettersBounds()
          : null;
      if (from != null) _rungController.reset();
      setState(() {
        _levelComplete = false;
        _selectedLetter = null;
        _currentRung++;
        if (!isWon) {
          _existingLetterCount = solved.length;
          _flightFrom = from;
          _flightTo = null;
          _filledLetters[_currentRung] = solved
            ..addAll(currentLevel.lettersToAdd);
        }
      });
      if (isWon) {
        _persistState().then((saved) {
          if (saved && mounted) setState(() => _showWinningView = true);
        });
      } else {
        if (_rungInFlight) {
          _persistState();
          _startRungTransition();
        } else {
          _checkActiveRow(delayed: true);
        }
        _scrollToActiveRow();
      }
    });
  }

  Rect? _activeLettersBounds() {
    final row = _activeLettersKey.currentContext?.findRenderObject();
    final layer = _boardLayerKey.currentContext?.findRenderObject();
    if (row is! RenderBox ||
        layer is! RenderBox ||
        !row.hasSize ||
        !layer.hasSize) {
      debugPrint('Rung transition skipped: the letter row is not laid out.');
      return null;
    }
    // Both endpoints scroll with the board rather than the screen.
    return row.localToGlobal(Offset.zero, ancestor: layer) & row.size;
  }

  void _startRungTransition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rungInFlight) return;
      final target = _activeLettersBounds();
      if (target == null) {
        _rungController.value = 1;
        return;
      }
      setState(() => _flightTo = target);
      _rungController.forward();
    });
  }

  void _finishRungTransition() {
    if (!mounted || !_rungInFlight) return;
    setState(() {
      _flightFrom = null;
      _flightTo = null;
    });
    _checkActiveRow(delayed: true);
    _scrollToActiveRow();
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
