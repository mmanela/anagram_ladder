import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:anagram_ladder/navigation/gameRouteInformationParser.dart';
import 'package:anagram_ladder/navigation/gameRouterDelegate.dart';
import 'package:anagram_ladder/pages/levelPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'level_page_test.dart' show setViewport;
import 'game_state_test.dart' show completedLevel;
import 'widget_test.dart' show startGame;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final wasFatal = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = wasFatal);
    PackageInfo.setMockInitialValues(
      appName: 'Anagram Ladder',
      packageName: 'com.farblondzshet.anagramladder',
      version: '1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('Continue returns directly to the saved letter arrangement', (
    tester,
  ) async {
    await startGame(tester);
    final state = tester.element(find.text('Play')).read<GameState>();
    final ladder = await state.getLevelOrLoad(6, 1);
    await state.persistLevelState(
      LevelState(6, 1, 0, 0, ladder.getBottomUp().length, [
        ['e', 's', 't', 'a'],
        ...ladder
            .getBottomUp()
            .skip(1)
            .map((rung) => List.filled(rung.letterCount, '')),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Choose a ladder'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(LevelPage), findsOneWidget);
    expect(find.text('Normal Ladder #1'), findsOneWidget);
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'esta');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('home supports large text without hiding its navigation', (
    tester,
  ) async {
    setViewport(tester, const Size(320, 568), textScale: 3);
    await startGame(tester);
    for (final label in ['Play', 'About', 'Settings']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('home uses the chosen tagline and simple daily wording', (
    tester,
  ) async {
    await startGame(tester);
    expect(find.text('Rearrange.\nSolve. Climb.'), findsOneWidget);
    expect(find.textContaining('Rearrange'), findsOneWidget);
    expect(
      find.text('Use every letter to make a word on each rung.'),
      findsOneWidget,
    );
    expect(find.text('One word.\nA little higher.'), findsNothing);
    final day = tester.element(find.text('Play')).read<GameState>().today;
    expect(find.text('${day.difficultyDescription}.'), findsOneWidget);
    expect(find.textContaining('free Normal ladder'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a loading store does not block home or free ladders', (
    tester,
  ) async {
    final store = GameStore();
    final state = GameState(store);
    final navigation = GameRouteNavigator();
    final router = GameRouterDelegate(navigation, state, store);
    addTearDown(router.dispose);
    addTearDown(state.dispose);
    addTearDown(store.dispose);
    addTearDown(navigation.dispose);
    await tester.runAsync(() => state.initialize());
    expect(store.isLoaded, isFalse);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider.value(value: navigation),
        ],
        child: MaterialApp.router(
          routerDelegate: router,
          routeInformationParser: GameRouteInformationParser(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
    navigation.goto(GameRoutePath.level(6, 1));
    await tester.pumpAndSettle();
    expect(find.byType(LevelPage), findsOneWidget);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(store.isLoaded, isFalse);
  });

  testWidgets('ten-letter rungs fit a narrow phone and remain tappable', (
    tester,
  ) async {
    setViewport(tester, const Size(320, 568));
    await startGame(tester);
    final context = tester.element(find.text('Play'));
    final state = context.read<GameState>();
    final progress = await completedLevel(state, 10, 1);
    progress.currentRung = progress.rungCount - 1;
    progress.levelLetters.last = progress.levelLetters.last.reversed.toList();
    await state.persistLevelState(progress);
    context.read<GameRouteNavigator>().goto(GameRoutePath.level(10, 1));
    await tester.pumpAndSettle();
    expect(find.text('Genius Ladder #1'), findsOneWidget);
    expect(
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .itemCount,
      10,
    );
    for (var index = 0; index < 10; index++) {
      final letter = find.byKey(ValueKey('letter-$index'));
      final rect = tester.getRect(letter);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.width, closeTo(29, 0.001));
      expect(rect.height, greaterThanOrEqualTo(64));
      expect(letter.hitTestable(), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('letter-0')));
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('letter-0')))
          .properties
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final letterCount in [8, 10]) {
    for (final (size, textScale, sideInset) in [
      (const Size(320, 568), 1.0, 0.0),
      (const Size(400, 800), 1.0, 0.0),
      (const Size(700, 320), 3.0, 44.0),
      (const Size(1024, 768), 1.0, 0.0),
    ]) {
      testWidgets('$letterCount active letters fill available width at $size, '
          '${textScale}x text, $sideInset side inset', (tester) async {
        setViewport(tester, size, textScale: textScale);
        tester.view.padding = FakeViewPadding(
          left: sideInset,
          right: sideInset,
        );
        addTearDown(tester.view.resetPadding);
        await startGame(tester);
        final context = tester.element(find.text('Play'));
        final state = context.read<GameState>();
        final ladder = await state.getLevelOrLoad(10, 1);
        final rungs = ladder.getBottomUp();
        final rung = rungs.indexWhere(
          (rung) => rung.letterCount == letterCount,
        );
        expect(rung, isNonNegative);
        final progress = await completedLevel(state, 10, 1);
        progress.currentRung = rung;
        progress.levelLetters[rung] = progress.levelLetters[rung].reversed
            .toList();
        expect(
          rungs[rung].words,
          isNot(contains(progress.levelLetters[rung].join())),
        );
        await state.persistLevelState(progress);
        context.read<GameRouteNavigator>().goto(GameRoutePath.level(10, 1));
        await tester.pumpAndSettle();

        final boardWidth = (size.width - sideInset * 2 - 16).clamp(0, 700);
        final expectedWidth = ((boardWidth - 14) / letterCount).clamp(0, 72);
        final card = tester.getRect(
          find
              .ancestor(
                of: find.byType(ReorderableListView),
                matching: find.byType(Container),
              )
              .first,
        );
        final first = find.byKey(const ValueKey('letter-0'));
        final last = find.byKey(ValueKey('letter-${letterCount - 1}'));
        for (var index = 0; index < letterCount; index++) {
          final letter = find.byKey(ValueKey('letter-$index'));
          final rect = tester.getRect(letter);
          expect(rect.width, closeTo(expectedWidth, 0.001));
          expect(rect.height, greaterThanOrEqualTo(64));
          expect(rect.left, greaterThanOrEqualTo(sideInset + 8));
          expect(rect.right, lessThanOrEqualTo(size.width - sideInset - 8));
          final paintedTile = find.descendant(
            of: letter,
            matching: find.byType(DecoratedBox),
          );
          expect(
            tester.getSize(paintedTile).width,
            closeTo(expectedWidth - 2, 0.001),
          );
          final paintedRect = tester.getRect(paintedTile);
          expect(paintedRect.left - card.left, greaterThanOrEqualTo(8 - 0.001));
          expect(
            card.right - paintedRect.right,
            greaterThanOrEqualTo(8 - 0.001),
          );
          expect(letter.hitTestable(), findsOneWidget);
        }
        final before = List<String>.of(progress.levelLetters[rung]);
        await tester.tap(first);
        await tester.pump();
        await tester.tap(last);
        await tester.pumpAndSettle();
        final afterTap = [...before.skip(1), before.first];
        expect(state.getLevelState(10, 1).levelLetters[rung], afterTap);
        final start = tester.getCenter(first);
        final destination = tester.getCenter(
          find.byKey(const ValueKey('letter-2')),
        );
        final gesture = await tester.startGesture(start);
        for (var step = 1; step <= 6; step++) {
          await gesture.moveTo(Offset.lerp(start, destination, step / 6)!);
          await tester.pump(const Duration(milliseconds: 60));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(state.getLevelState(10, 1).levelLetters[rung], [
          afterTap[1],
          afterTap[2],
          afterTap[0],
          ...afterTap.skip(3),
        ]);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  }

  testWidgets('difficulty and ladder selectors support large text', (
    tester,
  ) async {
    setViewport(tester, const Size(320, 568), textScale: 3);
    await startGame(tester);
    final navigation = tester
        .element(find.text('Play'))
        .read<GameRouteNavigator>();
    navigation.goto(GameRoutePath.worldSet());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Genius'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Genius'));
    await tester.pumpAndSettle();
    expect(find.text('Genius Ladders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('level selection names completed, partial, and new ladders', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await startGame(tester);
      final context = tester.element(find.text('Play'));
      final state = context.read<GameState>();
      await state.persistLevelState(await completedLevel(state, 6, 1));
      final partial = await completedLevel(state, 6, 2);
      partial.currentRung = 1;
      await state.persistLevelState(partial);
      context.read<GameRouteNavigator>().goto(GameRoutePath.world(6));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Ladder 1, completed'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Ladder 2, 1 of 3 rungs solved'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Ladder 3, not started'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Settings toggles haptics and confirms reset at large text', (
    tester,
  ) async {
    setViewport(tester, const Size(320, 568), textScale: 3);
    await startGame(tester);
    final context = tester.element(find.text('Play'));
    final state = context.read<GameState>();
    await state.persistLevelState(await completedLevel(state, 6, 1));
    context.read<GameRouteNavigator>().goto(GameRoutePath.settings());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(state.hapticsEnabled, isFalse);
    await tester.scrollUntilVisible(
      find.text('Reset progress'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(state.getLevelState(6, 1).isWon, isTrue);
    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Reset progress'),
        ),
      );
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(state.getLevelState(6, 1).isEmpty, isTrue);
    expect(state.resumeLevel, isNull);
    expect(state.hapticsEnabled, isFalse);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
