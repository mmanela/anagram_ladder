import 'dart:ui' show PointerDeviceKind;

import 'package:anagram_ladder/components/rungTransition.dart';
import 'package:anagram_ladder/pages/levelPage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'level_page_test.dart' show arrangeWord, openFixture, setViewport;
import 'game_store_test.dart' show TestPurchasePlatform;
import 'widget_test.dart' show startGame;

Finder letterFocus(int index) => find
    .descendant(
      of: find.byKey(ValueKey('letter-$index')),
      matching: find.byType(Focus),
    )
    .first;

void focusLetter(WidgetTester tester, int index) {
  tester.widget<Focus>(letterFocus(index)).focusNode!.requestFocus();
}

void main() {
  late TestPurchasePlatform purchasePlatform;
  setUpAll(() {
    // Host widget tests must not register native StoreKit listeners.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
    purchasePlatform = TestPurchasePlatform();
    InAppPurchasePlatform.instance = purchasePlatform;
  });
  tearDownAll(() => purchasePlatform.updates.close());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Tab reaches letters and arrows move the focused letter', (
    tester,
  ) async {
    setViewport(tester, const Size(900, 760));
    final state = await openFixture(tester);
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if (tester.widget<Focus>(letterFocus(0)).focusNode!.hasFocus) break;
    }
    expect(tester.widget<Focus>(letterFocus(0)).focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'tars');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'atrs');
    expect(tester.widget<Focus>(letterFocus(1)).focusNode!.hasFocus, isTrue);
    expect(state.controlsLearned, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'arts');
    expect(tester.widget<Focus>(letterFocus(2)).focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'atrs');
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('keyboard selection supports Space, Enter and Escape', (
    tester,
  ) async {
    final state = await openFixture(tester);
    focusLetter(tester, 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('letter-0')))
          .properties
          .selected,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('letter-0')))
          .properties
          .selected,
      isFalse,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    focusLetter(tester, 2);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'arts');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('modified arrows do not reorder letters', (tester) async {
    final state = await openFixture(tester);
    focusLetter(tester, 0);
    await tester.pump();
    for (final modifier in [
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.altLeft,
    ]) {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
      expect(state.getLevelState(6, 1).levelLetters.first.join(), 'tars');
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('keyboard cannot change solved or transitioning letters', (
    tester,
  ) async {
    setViewport(tester, const Size(900, 760));
    final state = await openFixture(tester, middleWords: ['rates']);
    focusLetter(tester, 0);
    await tester.pump();
    await arrangeWord(tester, state, 'star');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'star');
    await tester.pump(LevelPage.solveDuration);
    await tester.pump();
    expect(find.byType(RungTransition), findsOneWidget);
    focusLetter(tester, 0);
    await tester.pump();
    final before = state.getLevelState(6, 1).levelLetters[1].join();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(state.getLevelState(6, 1).levelLetters[1].join(), before);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('mouse dragging reorders tiles and resize keeps them visible', (
    tester,
  ) async {
    setViewport(tester, const Size(900, 760));
    final state = await openFixture(tester);
    final start = tester.getCenter(find.byKey(const ValueKey('letter-0')));
    final end = tester.getCenter(find.byKey(const ValueKey('letter-2')));
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(Offset.lerp(start, end, step / 6)!);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.getLevelState(6, 1).levelLetters.first.join(), 'arts');
    for (final size in [const Size(480, 480), const Size(1440, 900)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      for (var index = 0; index < 4; index++) {
        final tile = find.byKey(ValueKey('letter-$index'));
        expect(tile.hitTestable(), findsOneWidget);
        expect(tester.getRect(tile).right, lessThanOrEqualTo(size.width));
      }
      expect(tester.takeException(), isNull);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('native Mac Settings action opens Settings from home', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await startGame(tester);
    expect(find.text('Store'), findsOneWidget);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'anagram_ladder/menu',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('settings'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Reset progress'), findsOneWidget);
    expect(find.text('Play'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
