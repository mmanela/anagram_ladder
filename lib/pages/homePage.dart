import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final navigation = context.read<GameRouteNavigator>();
    final resume = game.resumeLevel;
    final progress = resume == null
        ? null
        : game.getLevelState(resume.world!, resume.level!);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.stairs_rounded,
                        color: colors.primary,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Anagram Ladder',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Rearrange.\nSolve. Climb.',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rearrange the letters. Find a word. Climb to the next one.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            resume == null
                                ? 'Your first ladder is waiting'
                                : '${GameState.worldLabels[resume.world]}'
                                      ' Ladder #${resume.level}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            progress == null || progress.isEmpty
                                ? 'Choose a difficulty and take your time.'
                                : '${progress.currentRung} of '
                                      '${progress.rungCount} rungs solved. '
                                      'Pick up where you left off.',
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () => navigation.goto(
                              resume ?? GameRoutePath.worldSet(),
                            ),
                            child: Text(resume == null ? 'Play' : 'Continue'),
                          ),
                          if (resume != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () =>
                                  navigation.goto(GameRoutePath.worldSet()),
                              child: const Text('Choose a ladder'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(20),
                      leading: Icon(
                        Icons.today_outlined,
                        color: colors.primary,
                      ),
                      title: const Text('Daily ladder'),
                      subtitle: Text(
                        game.isDailyCompleted(game.today)
                            ? 'Completed today'
                            : 'A Normal ladder each day.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => navigation.goto(GameRoutePath.daily()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => navigation.goto(GameRoutePath.about()),
                        child: const Text('About'),
                      ),
                      TextButton(
                        onPressed: () =>
                            navigation.goto(GameRoutePath.settings()),
                        child: const Text('Settings'),
                      ),
                      if (defaultTargetPlatform != TargetPlatform.android)
                        TextButton(
                          onPressed: () => navigation.goto(GameRoutePath.pay()),
                          child: const Text('Store'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
