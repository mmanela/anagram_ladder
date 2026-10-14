import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorldSetPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final navigation = context.read<GameRouteNavigator>();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pick your difficulty')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Choose your climb. Every ladder saves your progress, '
                  'so there is no rush.',
                ),
                const SizedBox(height: 24),
                for (final world in GameState.worldIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            navigation.goto(GameRoutePath.world(world)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.stairs_rounded,
                                color: colors.primary,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      GameState.worldLabels[world]!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Up to $world letters'),
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(
                                      value: game
                                          .getWorldCompletionInfo(world)
                                          .percent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${game.getWorldCompletionInfo(world).completedCount}'
                                      ' / ${game.getWorldCompletionInfo(world).levelCount}'
                                      ' complete',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
