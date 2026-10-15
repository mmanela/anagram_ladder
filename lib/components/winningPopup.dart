import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WinningPopup extends StatefulWidget {
  final VoidCallback resetLevel;
  final bool wasPlayed;
  final int world;
  final int level;
  const WinningPopup({
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
  bool _celebrated = false;
  _WinningPopupState();

  @override
  void initState() {
    super.initState();
    _controllerCenter = ConfettiController(
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controllerCenter.stop();
      return;
    }
    final game = context.read<GameState>();
    if (!_celebrated &&
        widget.wasPlayed &&
        (game.isWorldDone(widget.world) || game.isGameDone())) {
      _celebrated = true;
      _controllerCenter.play();
    }
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
    return BlockSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(dismissible: false, color: Color(0x66292437)),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Semantics(
                scopesRoute: true,
                explicitChildNodes: true,
                child: FocusTraversalGroup(child: _dialogBody(context)),
              ),
            ),
          ),
          if (!MediaQuery.disableAnimationsOf(context))
            IgnorePointer(
              child: ExcludeSemantics(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _controllerCenter,
                    emissionFrequency: 0.02,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dialogBody(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final gameState = context.read<GameState>();
    final nextLevel = gameState.getNextUnfinishedLevel(
      widget.world,
      widget.level,
    );
    final isWorldDone = gameState.isWorldDone(widget.world);
    final isGameDone = gameState.isGameDone();
    final completion = gameState.getWorldCompletionInfo(widget.world);
    final worldName = GameState.worldLabels[widget.world];
    final milestone = widget.wasPlayed && (isWorldDone || isGameDone);
    final nav = context.read<GameRouteNavigator>();

    var label = "Level Complete!";
    var message = 'Every rung solved. Nicely done.';
    if (widget.wasPlayed) {
      if (isGameDone) {
        label = "You beat the game!";
        message = 'Every ladder, every difficulty. What a climb.';
      } else if (isWorldDone) {
        label = "$worldName difficulty complete!";
        message = 'Every $worldName ladder solved. What a climb.';
      }
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: milestone
                        ? colors.primaryContainer
                        : const Color(0xFFE8F3EC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    milestone
                        ? Icons.emoji_events_rounded
                        : Icons.check_rounded,
                    color: milestone
                        ? colors.onPrimaryContainer
                        : const Color(0xFF256144),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$worldName / Ladder #${widget.level}',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                namesRoute: true,
                header: true,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (completion.levelCount > 0) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '$worldName progress',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: completion.percent,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(6),
                        semanticsLabel: '$worldName difficulty progress',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${completion.completedCount} of '
                        '${completion.levelCount} ladders complete',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (nextLevel != null) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onPressed: () => nav.goto(nextLevel),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next Level', textAlign: TextAlign.center),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () => nav.goto(GameRoutePath.world(widget.world)),
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Level Screen', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: widget.resetLevel,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Restart', textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
