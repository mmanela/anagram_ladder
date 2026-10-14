import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:anagram_ladder/pages/levelPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'level_page_test.dart' show setViewport;
import 'game_state_test.dart' show completedLevel;
import 'widget_test.dart' show startGame;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
}
