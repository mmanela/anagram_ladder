import 'dart:math';

import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorldPage extends StatelessWidget {
  final int world;

  WorldPage(this.world);

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final navigation = context.read<GameRouteNavigator>();
    final info = game.getWorldCompletionInfo(world);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${GameState.worldLabels[world]} Ladders')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${info.completedCount} of ${info.levelCount} complete',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: info.percent),
                        const SizedBox(height: 12),
                        const Text('Pick any ladder. Your place is saved.'),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final extent = max(
                        96.0,
                        MediaQuery.textScalerOf(context).scale(28) + 68,
                      );
                      final columns = max(
                        1,
                        (constraints.crossAxisExtent / extent).floor(),
                      );
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final level = index + 1;
                          final progress = game.getLevelState(world, level);
                          final started = !progress.isEmpty;
                          final status = progress.isWon
                              ? 'completed'
                              : started
                              ? '${progress.currentRung} of '
                                    '${progress.rungCount} rungs solved'
                              : 'not started';
                          void open() => navigation.goto(
                            GameRoutePath.level(world, level),
                          );
                          return Semantics(
                            button: true,
                            label: 'Ladder $level, $status',
                            onTap: open,
                            child: ExcludeSemantics(
                              child: Card(
                                color: progress.isWon
                                    ? const Color(0xFFE8F3EC)
                                    : started
                                    ? colors.primaryContainer
                                    : null,
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: open,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '$level',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: progress.isWon
                                                        ? const Color(
                                                            0xFF256144,
                                                          )
                                                        : colors.onSurface,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (progress.isWon)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF256144),
                                            size: 20,
                                          )
                                        else
                                          LinearProgressIndicator(
                                            value: started
                                                ? progress.percentComplete
                                                : 0,
                                            minHeight: 4,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }, childCount: game.maxLevelsPerWorld),
                      );
                    },
                  ),
                ),
                if (game.shouldAdverstiseMoreLevels)
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: OutlinedButton.icon(
                        onPressed: () => navigation.goto(
                          GameRoutePath.pay(
                            source: GameRoutePage.World,
                            world: world,
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Unlock more levels'),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
