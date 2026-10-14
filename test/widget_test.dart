import 'package:anagram_ladder/anagram/anagramBuilder.dart';
import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/components/fixedLetterRow.dart';
import 'package:anagram_ladder/components/letterBoxDimensions.dart';
import 'package:anagram_ladder/components/winningPopup.dart';
import 'package:anagram_ladder/main.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:anagram_ladder/pages/levelPage.dart';
import 'package:anagram_ladder/pages/loadingPage.dart';
import 'package:anagram_ladder/pages/unknownPage.dart';
import 'package:anagram_ladder/pages/worldPage.dart';
import 'package:anagram_ladder/pages/worldSet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> startGame(WidgetTester tester) async {
  await tester.runAsync(() async {
    await SharedPreferences.getInstance();
    for (final world in GameState.worldIds) {
      await rootBundle.loadString(
        AnagramLadderBuilder.getGameLadderSetPath(world),
      );
    }
  });
  await tester.pumpWidget(AnagramLadderApp());
  await tester.runAsync(() async {
    final state = tester.element(find.byType(LoadingPage)).read<GameState>();
    for (var attempt = 0; attempt < 100 && !state.isLoaded; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(state.isLoaded, isTrue);
  });
  await tester.pumpAndSettle();
  expect(find.text('Play'), findsOneWidget);
}

Future<LadderLevel> openLevelAtLastRung(
  WidgetTester tester, {
  bool completed = false,
}) async {
  // Keep the fixed-size popup inside the viewport with the test font's wide glyphs.
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 0.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await startGame(tester);
  final context = tester.element(find.text('Play'));
  final state = context.read<GameState>();
  final navigation = context.read<GameRouteNavigator>();
  final ladder = await state.getLevelOrLoad(6, 1);
  final rungs = ladder.getBottomUp();
  final solution = ladder.words.firstWhere((word) {
    final rotated = word.substring(1) + word[0];
    return !ladder.words.contains(rotated);
  });
  final letters = rungs.map((rung) => rung.words.first.split('')).toList();
  letters.last = completed
      ? solution.split('')
      : (solution.substring(1) + solution[0]).split('');
  await state.persistLevelState(
    LevelState(
      6,
      1,
      completed ? ladder.letterCount : rungs[rungs.length - 2].letterCount,
      completed ? rungs.length : rungs.length - 1,
      rungs.length,
      letters,
    ),
  );
  navigation.goto(GameRoutePath.level(6, 1));
  await tester.pumpAndSettle();
  return ladder;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('startup, difficulty selection, and back navigation still work', (
    tester,
  ) async {
    await startGame(tester);
    expect(find.text('Store'), findsNothing);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.byType(WorldSetPage), findsOneWidget);

    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();
    expect(find.byType(WorldPage), findsOneWidget);
    expect(find.text('Normal Ladders'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WorldSetPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);

    await tester.ensureVisible(find.text('About'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('What is Anagram Ladder?'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('programmatic page removals do not override the selected route', (
    tester,
  ) async {
    await startGame(tester);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    final navigation = tester
        .element(find.byType(WorldSetPage))
        .read<GameRouteNavigator>();
    navigation.goto(GameRoutePath.about());
    await tester.pumpAndSettle();
    expect(navigation.current.page, GameRoutePage.About);
    expect(find.text('What is Anagram Ladder?'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('reordering uses the new adjusted index and persists progress', (
    tester,
  ) async {
    await startGame(tester);
    final homeContext = tester.element(find.text('Play'));
    final state = homeContext.read<GameState>();
    final navigation = homeContext.read<GameRouteNavigator>();
    final ladder = await state.getLevelOrLoad(6, 1);
    final rungs = ladder.getBottomUp();
    final letters = [
      ['e', 's', 't', 'a'],
      ...rungs.skip(1).map((rung) => List.filled(rung.letterCount, '')),
    ];
    expect(rungs.first.words, isNot(contains('esta')));
    expect(rungs.first.words, isNot(contains('stae')));
    await state.persistLevelState(
      LevelState(6, 1, 0, 0, rungs.length, letters),
    );
    navigation.goto(GameRoutePath.level(6, 1));
    await tester.pumpAndSettle();

    final reorderable = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    final before = List<String>.of(
      state.getLevelState(6, 1).levelLetters.first,
    );
    final expected = List<String>.of(before);
    expected.insert(expected.length - 1, expected.removeAt(0));
    reorderable.onReorderItem!(0, before.length - 1);
    await tester.pump();

    expect(state.getLevelState(6, 1).levelLetters.first, expected);
    reorderable.onReorderItem!(before.length - 1, 0);
    await tester.pump();
    expect(state.getLevelState(6, 1).levelLetters.first, before);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    navigation.goto(GameRoutePath.world(6));
    await tester.pumpAndSettle();
    expect(find.byType(LevelPage), findsNothing);
    expect(find.byType(WorldPage), findsOneWidget);
    expect(navigation.current.page, GameRoutePage.World);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('level completion appears after solving the final rung', (
    tester,
  ) async {
    final ladder = await openLevelAtLastRung(tester);
    final reorderable = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    reorderable.onReorderItem!(ladder.letterCount - 1, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byType(WinningPopup), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.byType(WinningPopup), findsOneWidget);
    expect(find.text('Level Complete!'), findsOneWidget);
    await tester.pumpAndSettle();
    final state = tester.element(find.byType(LevelPage)).read<GameState>();
    expect(state.getLevelState(6, 1).isWon, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('restarting a completed level immediately dismisses the popup', (
    tester,
  ) async {
    await openLevelAtLastRung(tester, completed: true);
    expect(find.byType(WinningPopup), findsOneWidget);

    await tester.tap(find.text('Restart'));
    await tester.pump();
    expect(find.byType(WinningPopup), findsNothing);
    await tester.pumpAndSettle();

    expect(find.byType(WinningPopup), findsNothing);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.text('Normal Ladder #1'), findsOneWidget);
    final state = tester.element(find.byType(LevelPage)).read<GameState>();
    final progress = state.getLevelState(6, 1);
    expect(progress.currentRung, 0);
    expect(progress.isWon, isFalse);
    expect(progress.levelLetters.first, hasLength(4));
    expect(
      progress.levelLetters.skip(1).expand((letters) => letters),
      everyElement(isEmpty),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a restarted level stays reset after leaving and reopening', (
    tester,
  ) async {
    final ladder = await openLevelAtLastRung(tester);
    final reorderable = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    reorderable.onReorderItem!(ladder.letterCount - 1, 0);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(WinningPopup), findsOneWidget);

    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    expect(find.byType(WinningPopup), findsNothing);
    final context = tester.element(find.byType(LevelPage));
    final state = context.read<GameState>();
    final navigation = context.read<GameRouteNavigator>();
    final resetLetters = state.getLevelState(6, 1).levelLetters;

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WorldPage), findsOneWidget);
    navigation.goto(GameRoutePath.level(6, 1));
    await tester.pumpAndSettle();

    expect(find.byType(WinningPopup), findsNothing);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(state.getLevelState(6, 1).currentRung, 0);
    expect(state.getLevelState(6, 1).levelLetters, resetLetters);
    expect(state.getWorldCompletionInfo(6).completedCount, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'next level dismisses completion and opens the next playable level',
    (tester) async {
      await openLevelAtLastRung(tester, completed: true);
      expect(find.byType(WinningPopup), findsOneWidget);

      await tester.tap(find.text('Next Level'));
      await tester.pumpAndSettle();

      expect(find.byType(WinningPopup), findsNothing);
      expect(find.text('Normal Ladder #2'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
      final navigation = tester
          .element(find.byType(LevelPage))
          .read<GameRouteNavigator>();
      expect(navigation.current.page, GameRoutePage.Level);
      expect(navigation.current.world, 6);
      expect(navigation.current.level, 2);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('leaving during the completion animation cancels UI updates', (
    tester,
  ) async {
    final ladder = await openLevelAtLastRung(tester);
    final navigation = tester
        .element(find.byType(LevelPage))
        .read<GameRouteNavigator>();
    final reorderable = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    reorderable.onReorderItem!(ladder.letterCount - 1, 0);
    await tester.pump();
    navigation.goto(GameRoutePath.world(6));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(LevelPage), findsNothing);
    expect(find.byType(WorldPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'a solved final rung survives leaving before the animation ends',
    (tester) async {
      final ladder = await openLevelAtLastRung(tester);
      final context = tester.element(find.byType(LevelPage));
      final navigation = context.read<GameRouteNavigator>();
      final state = context.read<GameState>();
      final reorderable = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      reorderable.onReorderItem!(ladder.letterCount - 1, 0);
      await tester.pump();
      final solved = state.getLevelState(6, 1).levelLetters.last.join();
      expect(ladder.words, contains(solved));

      navigation.goto(GameRoutePath.world(6));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.runAsync(() => state.initialize(force: true));
      expect(state.getLevelState(6, 1).levelLetters.last.join(), solved);

      navigation.goto(GameRoutePath.level(6, 1));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(state.getLevelState(6, 1).isWon, isTrue);
      expect(state.getWorldCompletionInfo(6).completedCount, 1);
      expect(find.byType(WinningPopup), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'links to unavailable levels show the invalid page, not a crash',
    (tester) async {
      await startGame(tester);
      final context = tester.element(find.text('Play'));
      final router = Router.of(context).routerDelegate;
      await router.setNewRoutePath(GameRoutePath.level(6, 51));
      await tester.pumpAndSettle();
      expect(find.byType(UnknownPage), findsOneWidget);
      expect(find.byType(LevelPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('letter text scaling keeps the existing board size cap', (
    tester,
  ) async {
    late LetterBoxDimensions dimensions;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            textScaler: TextScaler.linear(3),
          ),
          child: Builder(
            builder: (context) {
              dimensions = LetterBoxDimensions(context, 6, 3);
              return Scaffold(
                body: FixedLetterRow([
                  'a',
                  'b',
                  'c',
                  'd',
                  'e',
                  'f',
                ], dimensions),
              );
            },
          ),
        ),
      ),
    );

    final letter = tester.widget<Text>(find.text('a'));
    expect(letter.textScaler!.scale(30), 37.5);
    expect(dimensions.boxWidth, closeTo(380 / 6, 0.001));
    expect(tester.takeException(), isNull);
  });
}
