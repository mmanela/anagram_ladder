import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final today = game.today;
    LevelState? progress;
    Object? loadError;
    try {
      progress = game.getDailyState(today);
    } catch (error) {
      debugPrint('Daily ladder: could not read progress: $error');
      loadError = error;
    }
    final completed = game.isDailyCompleted(today);
    return Scaffold(
      appBar: AppBar(title: const Text('Daily ladder')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  today.dateKey,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'A little climb, every day.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  today.difficultyDescription,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The same puzzle for everyone on this date. '
                  'Difficulty varies from day to day. '
                  'A new puzzle arrives at midnight in your local time. '
                  'Your regular ladders are untouched.',
                ),
                if (completed) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Completed today',
                    style: TextStyle(
                      color: const Color(0xFF256144),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (loadError != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Could not read your daily progress. '
                            'Your saved data has not been changed.',
                          ),
                          TextButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: () => context.read<GameRouteNavigator>().goto(
                      GameRoutePath.dailyLevel(today.dateKey),
                    ),
                    child: Text(
                      progress!.isWon
                          ? 'View completed ladder'
                          : progress.isEmpty
                          ? 'Play daily ladder'
                          : 'Continue daily ladder',
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
