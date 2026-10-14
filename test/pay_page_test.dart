import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/pages/payPage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:provider/provider.dart';

import 'game_store_test.dart'
    show TestPurchasePlatform, testProduct, purchaseUpdate;
import 'level_page_test.dart' show setViewport;

void main() {
  late InAppPurchasePlatform originalPlatform;
  late TestPurchasePlatform platform;
  late GameStore store;

  setUp(() async {
    final target = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      expect(InAppPurchase.instance, isNotNull);
    } finally {
      debugDefaultTargetPlatformOverride = target;
    }
    originalPlatform = InAppPurchasePlatform.instance;
    platform = TestPurchasePlatform()..products.add(testProduct());
    InAppPurchasePlatform.instance = platform;
    store = GameStore();
    final wasFatal = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = wasFatal);
  });

  tearDown(() async {
    store.dispose();
    await platform.updates.close();
    InAppPurchasePlatform.instance = originalPlatform;
  });

  Future<void> openStore(WidgetTester tester) async {
    await store.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(home: PayPage()),
      ),
    );
  }

  testWidgets('failed buys show an error and Retry reconnects', (tester) async {
    platform.purchaseStarted = false;
    await openStore(tester);
    await tester.tap(find.text(r'Unlock for $2.99'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be started'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PayPage),
        matching: find.byType(ModalBarrier),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Retry connection'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be started'), findsNothing);
    expect(platform.queryCalls, 2);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Restore Purchases records restored entitlements in the UI', (
    tester,
  ) async {
    await openStore(tester);
    await tester.tap(find.text('Restore Purchases'));
    await tester.pumpAndSettle();
    expect(platform.restoreCalls, 2);
    expect(find.textContaining('Restore requested'), findsOneWidget);
    platform.updates.add([purchaseUpdate(PurchaseStatus.restored)]);
    await tester.pumpAndSettle();
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.text(r'Unlock for $2.99'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('store actions remain reachable on a small phone at large text', (
    tester,
  ) async {
    setViewport(tester, const Size(320, 568), textScale: 3);
    await openStore(tester);
    await tester.scrollUntilVisible(
      find.text(r'Unlock for $2.99'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'Unlock for $2.99').hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Restore Purchases'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restore Purchases').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
