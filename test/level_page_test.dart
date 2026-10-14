import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/components/hintDialog.dart';
import 'package:anagram_ladder/components/winningPopup.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/pages/levelPage.dart';
import 'package:anagram_ladder/pages/payPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixtureGameState extends GameState {
  final LadderLevel ladder;

  FixtureGameState(super.store, this.ladder);

  @override
  Future<LadderLevel> getLevelOrLoad(int worldNum, int level) async => ladder;
}

LadderLevel testLadder({
  String finalWord = 'stared',
  List<String> middleWords = const ['stare'],
}) {
  final bottom = LadderLevel.bottom(['a', 'r', 's', 't'], 2, ['star', 'rats']);
  final middle = LadderLevel(
    ['a', 'e', 'r', 's', 't'],
    middleWords.length,
    bottom,
    middleWords,
  );
  return LadderLevel(['a', 'd', 'e', 'r', 's', 't'], 1, middle, [finalWord]);
}

void setViewport(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<FixtureGameState> openFixture(
  WidgetTester tester, {
  bool completed = false,
  String finalWord = 'stared',
  List<String> middleWords = const ['stare'],
}) async {
  final store = GameStore();
  final state = FixtureGameState(
    store,
    testLadder(finalWord: finalWord, middleWords: middleWords),
  );
  final navigation = GameRouteNavigator();
  addTearDown(state.dispose);
  addTearDown(store.dispose);
  addTearDown(navigation.dispose);
  await tester.runAsync(() async {
    await state.initialize();
    await state.persistLevelState(
      LevelState(
        6,
        1,
        completed ? 6 : 0,
        completed ? 3 : 0,
        3,
        completed
            ? [
                ['s', 't', 'a', 'r'],
                ['s', 't', 'a', 'r', 'e'],
                finalWord.split(''),
              ]
            : [
                ['t', 'a', 'r', 's'],
                List.filled(5, ''),
                List.filled(6, ''),
              ],
      ),
    );
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: state),
        ChangeNotifierProvider<GameRouteNavigator>.value(value: navigation),
      ],
      child: MaterialApp(home: LevelPage(6, 1)),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

Future<void> arrangeWord(
  WidgetTester tester,
  GameState state,
  String word,
) async {
  final progress = state.getLevelState(6, 1);
  final letters = List<String>.of(progress.levelLetters[progress.currentRung]);
  for (var i = 0; i < word.length; i++) {
    if (letters[i] == word[i]) {
      continue;
    }
    final oldIndex = letters.indexOf(word[i], i + 1);
    expect(oldIndex, greaterThanOrEqualTo(0));
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(oldIndex, i);
    letters.insert(i, letters.removeAt(oldIndex));
    await tester.pump();
  }
}

Future<void> finishAnimation(WidgetTester tester) async {
  await tester.pump(LevelPage.solveDuration);
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final wasFatal = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = wasFatal);
  });

  testWidgets('a solved word automatically cascades through successive rungs', (
    tester,
  ) async {
    setViewport(tester, const Size(900, 1200), textScale: 0.75);
    final state = await openFixture(tester);
    await arrangeWord(tester, state, 'star');
    await tester.pump(const Duration(milliseconds: 319));
    expect(state.getLevelState(6, 1).currentRung, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(state.getLevelState(6, 1).currentRung, 1);
    expect(state.getLevelState(6, 1).levelLetters[1].join(), 'stare');

    await tester.pump(const Duration(milliseconds: 179));
    expect(state.getLevelState(6, 1).currentRung, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await finishAnimation(tester);
    expect(state.getLevelState(6, 1).currentRung, 2);
    expect(state.getLevelState(6, 1).levelLetters[2].join(), 'stared');
    await tester.pump(LevelPage.cascadeDelay);
    await finishAnimation(tester);
    expect(state.getLevelState(6, 1).isWon, isTrue);
    expect(state.getLevelState(6, 1).maxWordLength, 6);
    expect(state.getWorldCompletionInfo(6).completedCount, 1);
    expect(find.byType(WinningPopup), findsOneWidget);
  });

  testWidgets('reduced motion skips solve delays and tile animations', (
    tester,
  ) async {
    setViewport(tester, const Size(900, 1200), textScale: 0.75);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final state = await openFixture(tester);
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((widget) => widget.duration),
      everyElement(Duration.zero),
    );
    await arrangeWord(tester, state, 'star');
    await tester.pumpAndSettle();
    expect(state.getLevelState(6, 1).isWon, isTrue);
    expect(find.byType(WinningPopup), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap-to-move selects, moves, and persists without dragging', (
    tester,
  ) async {
    setViewport(tester, const Size(900, 1200), textScale: 0.75);
    final state = await openFixture(tester);
    await tester.tap(find.byKey(const ValueKey('letter-0')));
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('letter-0')))
          .properties
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('letter-1')));
    await tester.pumpAndSettle();
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'atrs');
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('letter-1')))
          .properties
          .selected,
      isFalse,
    );
  });

  testWidgets('horizontal tile dragging still reorders and saves letters', (
    tester,
  ) async {
    setViewport(tester, const Size(900, 1200), textScale: 0.75);
    final state = await openFixture(tester);
    final first = find.byKey(const ValueKey('letter-0'));
    final third = find.byKey(const ValueKey('letter-2'));
    final destination = tester.getCenter(third);
    final start = tester.getCenter(first);
    final gesture = await tester.startGesture(start);
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(Offset.lerp(start, destination, step / 6)!);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'arts');
  });

  testWidgets('vertical drags on a tile scroll without rearranging letters', (
    tester,
  ) async {
    setViewport(tester, const Size(320, 568));
    final state = await openFixture(tester);
    final scrollable = tester.state<ScrollableState>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    final before = scrollable.position.pixels;
    expect(before, greaterThan(0));
    await tester.drag(
      find.byKey(const ValueKey('letter-0')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, lessThan(before));
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'tars');
    expect(state.getLevelState(6, 1).currentRung, 0);
  });

  testWidgets('accessible move actions work and haptics can be disabled', (
    tester,
  ) async {
    final feedback = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') feedback.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    setViewport(tester, const Size(900, 1200), textScale: 0.75);
    final state = await openFixture(tester);
    await state.setHapticsEnabled(false);
    final tile = tester.widget<Semantics>(
      find.byKey(const ValueKey('letter-0')),
    );
    final actions = tile.properties.customSemanticsActions!;
    expect(actions.keys.map((action) => action.label), ['Move right']);
    actions.values.single();
    await tester.pump();
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'atrs');
    expect(feedback, isEmpty);
    await state.setHapticsEnabled(true);
    await tester.tap(find.byKey(const ValueKey('letter-0')));
    await tester.pump();
    expect(feedback.single.arguments, 'HapticFeedbackType.selectionClick');
  });

  testWidgets(
    'changing a word during the cascade delay does not auto-solve it',
    (tester) async {
      setViewport(tester, const Size(900, 1200), textScale: 0.75);
      final state = await openFixture(tester);
      await arrangeWord(tester, state, 'star');
      await finishAnimation(tester);
      expect(state.getLevelState(6, 1).currentRung, 1);
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(0, 4);
      await tester.pump();
      expect(state.getLevelState(6, 1).levelLetters[1].join(), 'tares');
      await tester.pump(LevelPage.cascadeDelay);
      await finishAnimation(tester);
      expect(state.getLevelState(6, 1).currentRung, 1);
      expect(find.byType(WinningPopup), findsNothing);
    },
  );

  testWidgets(
    'solving another valid word during a cascade advances only once',
    (tester) async {
      setViewport(tester, const Size(900, 1200), textScale: 0.75);
      final state = await openFixture(
        tester,
        finalWord: 'trades',
        middleWords: ['stare', 'rates'],
      );
      await arrangeWord(tester, state, 'star');
      await finishAnimation(tester);
      await arrangeWord(tester, state, 'rates');
      await tester.pump(LevelPage.cascadeDelay);
      await finishAnimation(tester);
      expect(state.getLevelState(6, 1).currentRung, 2);
      expect(state.getLevelState(6, 1).levelLetters[1].join(), 'rates');
      expect(state.getLevelState(6, 1).levelLetters[2].join(), 'ratesd');
      expect(find.byType(WinningPopup), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a full ladder can be completed again after restarting', (
    tester,
  ) async {
    setViewport(tester, const Size(900, 1200), textScale: 0.75);
    final state = await openFixture(tester, finalWord: 'trades');
    for (var play = 0; play < 2; play++) {
      await arrangeWord(tester, state, 'star');
      await finishAnimation(tester);
      await tester.pump(LevelPage.cascadeDelay);
      await finishAnimation(tester);
      expect(state.getLevelState(6, 1).currentRung, 2);
      expect(find.byType(WinningPopup), findsNothing);
      await arrangeWord(tester, state, 'trades');
      await finishAnimation(tester);
      expect(state.getLevelState(6, 1).isWon, isTrue);
      expect(state.getWorldCompletionInfo(6).completedCount, 1);
      expect(find.byType(WinningPopup), findsOneWidget);
      if (play == 0) {
        await tester.tap(find.text('Restart'));
        await tester.pump();
        expect(find.byType(WinningPopup), findsNothing);
        await tester.pumpAndSettle();
        expect(state.getLevelState(6, 1).currentRung, 0);
        expect(state.getWorldCompletionInfo(6).completedCount, 0);
      }
    }
  });

  testWidgets('hints reveal only selected letters and reset when reopened', (
    tester,
  ) async {
    setViewport(tester, const Size(900, 1200), textScale: 0.75);
    final state = await openFixture(tester);
    final before = state.getLevelState(6, 1).levelLetters;
    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();
    final hints = find.byType(WordHintControl);
    expect(hints, findsNWidgets(2));
    await tester.tap(
      find.descendant(of: hints.first, matching: find.text('Show first')),
    );
    await tester.pump();
    expect(
      find.descendant(of: hints.first, matching: find.text('s')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hints.first, matching: find.text('Show last')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hints.last, matching: find.text('Show first')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: hints.first, matching: find.text('Show last')),
    );
    await tester.pump();
    expect(
      find.descendant(of: hints.first, matching: find.text('r')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(HintDialog), findsNothing);
    expect(state.getLevelState(6, 1).currentRung, 0);
    expect(state.getLevelState(6, 1).levelLetters, before);

    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();
    expect(find.text('Show first'), findsNWidgets(2));
    expect(find.text('Show last'), findsNWidgets(2));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(HintDialog), findsNothing);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(state.getLevelState(6, 1).levelLetters, before);
  });

  testWidgets('a long hint list scrolls to its last word and close button', (
    tester,
  ) async {
    setViewport(tester, const Size(320, 568), textScale: 3);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  HintDialog.show(context, List.filled(30, 'star')),
              child: const Text('Hints'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Hints'));
    await tester.pumpAndSettle();
    final lastHint = find.byType(WordHintControl).last;
    final lastReveal = find.descendant(
      of: lastHint,
      matching: find.text('Show last'),
    );
    await tester.ensureVisible(lastReveal);
    await tester.pumpAndSettle();
    await tester.tap(lastReveal);
    await tester.pump();
    expect(
      find.descendant(of: lastHint, matching: find.text('r')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(HintDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  final layouts = [
    (name: 'small phone', size: const Size(320, 568), scale: 1.0),
    (name: 'landscape phone', size: const Size(568, 320), scale: 1.0),
    (name: 'large accessibility text', size: const Size(320, 568), scale: 3.0),
  ];
  for (final layout in layouts) {
    testWidgets('${layout.name} keeps gameplay, hints, and completion usable', (
      tester,
    ) async {
      setViewport(tester, layout.size, textScale: layout.scale);
      final state = await openFixture(tester, completed: true);
      expect(find.byType(WinningPopup), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Restart'));
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      expect(find.byType(WinningPopup), findsNothing);
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(state.getLevelState(6, 1).currentRung, 0);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Hint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hint'));
      await tester.pumpAndSettle();
      expect(find.byType(HintDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Show first').first);
      await tester.tap(find.text('Show first').first);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(HintDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('store blocking overlay disappears after cancellation or error', (
    tester,
  ) async {
    final store = GameStore()
      ..isAvailable = true
      ..storeEvent = StoreEvent.purchasePending;
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(home: PayPage()),
      ),
    );
    final barrier = find.descendant(
      of: find.byType(PayPage),
      matching: find.byType(ModalBarrier),
    );
    expect(barrier, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (final event in [StoreEvent.ready, StoreEvent.error]) {
      store.storeEvent = event;
      store.notifyListeners();
      await tester.pump();
      expect(barrier, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      store.storeEvent = StoreEvent.purchasePending;
      store.notifyListeners();
      await tester.pump();
      expect(barrier, findsOneWidget);
    }
    store.storeEvent = StoreEvent.ready;
    store.notifyListeners();
    await tester.pump();
  });
}
