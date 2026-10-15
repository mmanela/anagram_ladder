import 'package:anagram_ladder/components/winningPopup.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'level_page_test.dart' show setViewport;

class CompletionGameState extends GameState {
  final bool worldDone;
  final bool gameDone;

  CompletionGameState(
    super.store, {
    this.worldDone = false,
    this.gameDone = false,
  });

  @override
  WorldCompletionInfo getWorldCompletionInfo(int world) =>
      WorldCompletionInfo(50, worldDone || gameDone ? 50 : 1);

  @override
  bool isWorldDone(int world) => worldDone || gameDone;

  @override
  bool isGameDone() => gameDone;

  @override
  GameRoutePath? getNextUnfinishedLevel(int world, int level) => gameDone
      ? null
      : GameRoutePath.level(worldDone ? 7 : 6, worldDone ? 1 : 2);
}

Future<GameRouteNavigator> showCompletion(
  WidgetTester tester, {
  bool worldDone = false,
  bool gameDone = false,
  bool wasPlayed = true,
  VoidCallback? onRestart,
  VoidCallback? onBoardTap,
}) async {
  final store = GameStore();
  final state = CompletionGameState(
    store,
    worldDone: worldDone,
    gameDone: gameDone,
  );
  final navigation = GameRouteNavigator();
  addTearDown(store.dispose);
  addTearDown(state.dispose);
  addTearDown(navigation.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: state),
        ChangeNotifierProvider.value(value: navigation),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBoardTap,
                child: const Text('Board behind completion'),
              ),
              WinningPopup(
                wasPlayed: wasPlayed,
                world: 6,
                level: 1,
                resetLevel: onRestart ?? () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return navigation;
}

void main() {
  setUp(() {
    final wasFatal = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = wasFatal);
  });

  testWidgets('completion shows progress and keeps each action working', (
    tester,
  ) async {
    var restarts = 0;
    final nav = await showCompletion(tester, onRestart: () => restarts++);
    expect(find.text('Normal / Ladder #1'), findsOneWidget);
    expect(find.text('Level Complete!'), findsOneWidget);
    expect(find.text('1 of 50 ladders complete'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.02,
    );
    await tester.tap(find.text('Next Level'));
    expect(nav.current.world, 6);
    expect(nav.current.level, 2);
    await tester.tap(find.text('Level Screen'));
    expect(nav.current.page, GameRoutePage.World);
    expect(nav.current.world, 6);
    await tester.ensureVisible(find.text('Restart'));
    await tester.tap(find.text('Restart'));
    expect(restarts, 1);
  });

  testWidgets('completion blocks board taps and hides board semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var boardTaps = 0;
      await showCompletion(tester, onBoardTap: () => boardTaps++);
      await tester.tapAt(const Offset(5, 5));
      expect(boardTaps, 0);
      expect(find.bySemanticsLabel('Board behind completion'), findsNothing);
      expect(find.bySemanticsLabel('Level Complete!'), findsOneWidget);
      expect(find.byType(WinningPopup), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  for (final gameDone in [false, true]) {
    testWidgets(
      'new ${gameDone ? 'game' : 'difficulty'} completion celebrates',
      (tester) async {
        await showCompletion(tester, worldDone: true, gameDone: gameDone);
        expect(
          find.text(
            gameDone ? 'You beat the game!' : 'Normal difficulty complete!',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
        expect(find.text('50 of 50 ladders complete'), findsOneWidget);
        expect(
          find.text('Next Level'),
          gameDone ? findsNothing : findsOneWidget,
        );
        if (!gameDone) {
          await tester.tap(find.text('Next Level'));
          final nav = tester
              .element(find.byType(WinningPopup))
              .read<GameRouteNavigator>();
          expect(nav.current.world, 7);
          expect(nav.current.level, 1);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('reopened completion does not repeat milestone celebration', (
    tester,
  ) async {
    await showCompletion(tester, worldDone: true, wasPlayed: false);
    expect(find.text('Level Complete!'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_rounded), findsNothing);
    expect(find.text('50 of 50 ladders complete'), findsOneWidget);
  });

  testWidgets('reduced motion omits milestone confetti', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await showCompletion(tester, worldDone: true);
    expect(find.byType(ConfettiWidget), findsNothing);
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
  });

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(568, 320), 1.0),
    (const Size(320, 568), 3.0),
    (const Size(1024, 768), 1.0),
  ]) {
    testWidgets(
      'completion actions stay reachable at $size and ${scale}x text',
      (tester) async {
        setViewport(tester, size, textScale: scale);
        await showCompletion(tester);
        final card = tester.getRect(find.byType(Card));
        expect(card.width, lessThanOrEqualTo(420));
        expect(card.left, greaterThanOrEqualTo(20));
        expect(card.right, lessThanOrEqualTo(size.width - 20));
        for (final label in ['Next Level', 'Level Screen', 'Restart']) {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          expect(find.text(label).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
