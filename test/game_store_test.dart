import 'dart:async';

import 'package:anagram_ladder/models/gameStore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

class TestPurchasePlatform extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];
  bool available = true;
  IAPError? queryError;
  Completer<bool>? availability;
  final products = <ProductDetails>[];
  bool purchaseStarted = true;
  Object? purchaseError;
  Object? restoreError;
  Object? completionError;
  int purchaseCalls = 0;
  int restoreCalls = 0;
  int queryCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<bool> isAvailable() async => availability?.future ?? available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    queryCalls++;
    return ProductDetailsResponse(
      productDetails: products,
      notFoundIDs: [],
      error: queryError,
    );
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (completionError != null) throw completionError!;
    completed.add(purchase);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    purchaseCalls++;
    if (purchaseError != null) throw purchaseError!;
    return purchaseStarted;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    if (restoreError != null) throw restoreError!;
  }
}

ProductDetails testProduct() => ProductDetails(
  id: GameStore.productUnlock51to100,
  title: 'Extra ladders',
  description: '50 more ladders in every difficulty',
  price: r'$2.99',
  rawPrice: 2.99,
  currencyCode: 'USD',
);

PurchaseDetails purchaseUpdate(PurchaseStatus status) => PurchaseDetails(
  productID: GameStore.productUnlock51to100,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: '',
    source: 'test',
  ),
  transactionDate: '0',
  status: status,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestPurchasePlatform platform;
  late InAppPurchasePlatform originalPlatform;
  late GameStore store;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(InAppPurchase.instance, isNotNull);
    originalPlatform = InAppPurchasePlatform.instance;
    platform = TestPurchasePlatform();
    InAppPurchasePlatform.instance = platform;
    store = GameStore();
    await store.initialize();
  });

  tearDown(() async {
    store.dispose();
    await platform.updates.close();
    InAppPurchasePlatform.instance = originalPlatform;
    debugDefaultTargetPlatformOverride = null;
  });

  for (final needsCompletion in [false, true]) {
    test(
      'restored purchases unlock levels with pendingCompletePurchase=$needsCompletion',
      () async {
        final purchase = PurchaseDetails(
          productID: GameStore.productUnlock51to100,
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: '',
            source: 'test',
          ),
          transactionDate: '0',
          status: PurchaseStatus.restored,
        )..pendingCompletePurchase = needsCompletion;

        platform.updates.add([purchase]);
        await Future<void>.delayed(Duration.zero);

        expect(store.hasUnlocked51To100, isTrue);
        expect(store.storeEvent, StoreEvent.ready);
        expect(platform.completed, needsCompletion ? [purchase] : isEmpty);

        purchase.pendingCompletePurchase = false;
        platform.updates.add([purchase]);
        await Future<void>.delayed(Duration.zero);
        expect(store.purchases, hasLength(1));
      },
    );
  }

  test(
    'macOS keeps product queries, purchases and restoration enabled',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      store.dispose();
      store = GameStore();
      platform.products.add(testProduct());
      await store.initialize();
      expect(store.isAvailable, isTrue);
      expect(store.products.single.id, GameStore.productUnlock51to100);
      expect(platform.restoreCalls, 1);
      expect(await store.purchaseProduct(store.products.single), isTrue);
      expect(platform.purchaseCalls, 1);
      final purchase = purchaseUpdate(PurchaseStatus.purchased)
        ..pendingCompletePurchase = true;
      platform.updates.add([purchase]);
      await Future<void>.delayed(Duration.zero);
      expect(store.hasUnlocked51To100, isTrue);
      expect(platform.completed, [purchase]);
      await store.restorePurchases();
      expect(platform.restoreCalls, 2);
    },
  );

  test('disposing the store stops listening to purchase updates', () {
    expect(platform.updates.hasListener, isTrue);
    store.dispose();
    expect(platform.updates.hasListener, isFalse);
    // A fresh store lets tearDown dispose exactly once.
    store = GameStore();
  });

  test(
    'pending then canceled clears the blocking state without unlocking',
    () async {
      final events = <StoreEvent>[];
      store.addListener(() => events.add(store.storeEvent));
      platform.updates.add([purchaseUpdate(PurchaseStatus.pending)]);
      await Future<void>.delayed(Duration.zero);
      expect(store.storeEvent, StoreEvent.purchasePending);
      expect(store.hasUnlocked51To100, isFalse);

      platform.updates.add([purchaseUpdate(PurchaseStatus.canceled)]);
      await Future<void>.delayed(Duration.zero);
      expect(store.storeEvent, StoreEvent.ready);
      expect(store.errorMessage, isNull);
      expect(store.hasUnlocked51To100, isFalse);
      expect(platform.completed, isEmpty);
      expect(events, [StoreEvent.purchasePending, StoreEvent.ready]);
    },
  );

  test(
    'purchase errors clear pending and preserve the reported error',
    () async {
      platform.updates.add([purchaseUpdate(PurchaseStatus.pending)]);
      await Future<void>.delayed(Duration.zero);
      final failed = purchaseUpdate(PurchaseStatus.error)
        ..error = IAPError(
          source: 'test',
          code: 'failed',
          message: 'Payment failed',
        );
      platform.updates.add([failed]);
      await Future<void>.delayed(Duration.zero);

      expect(store.storeEvent, StoreEvent.error);
      expect(store.errorMessage, 'Payment failed');
      expect(store.hasUnlocked51To100, isFalse);
      expect(platform.completed, isEmpty);

      final purchased = purchaseUpdate(PurchaseStatus.purchased)
        ..pendingCompletePurchase = true;
      platform.updates.add([purchased]);
      await Future<void>.delayed(Duration.zero);
      expect(store.storeEvent, StoreEvent.ready);
      expect(store.errorMessage, isNull);
      expect(store.hasUnlocked51To100, isTrue);
      expect(platform.completed, [purchased]);
    },
  );

  test('purchase stream errors clear pending and notify the UI', () async {
    var notifications = 0;
    store.addListener(() => notifications++);
    platform.updates.add([purchaseUpdate(PurchaseStatus.pending)]);
    await Future<void>.delayed(Duration.zero);
    final error = StateError('Store connection lost');
    platform.updates.addError(error);
    await Future<void>.delayed(Duration.zero);

    expect(store.storeEvent, StoreEvent.error);
    expect(store.errorMessage, error.toString());
    expect(notifications, 2);
    expect(store.hasUnlocked51To100, isFalse);
  });

  test('an unavailable store finishes loading without unlocking', () async {
    store.dispose();
    platform.available = false;
    store = GameStore();
    await store.initialize();
    expect(store.isLoaded, isTrue);
    expect(store.isAvailable, isFalse);
    expect(store.storeEvent, StoreEvent.unavailable);
    expect(store.hasUnlocked51To100, isFalse);
  });

  test('product query errors are reported as a store error', () async {
    store.dispose();
    platform.queryError = IAPError(
      source: 'test',
      code: 'query-failed',
      message: 'Products could not be loaded',
    );
    store = GameStore();
    await store.initialize();
    expect(store.isLoaded, isTrue);
    expect(store.storeEvent, StoreEvent.error);
    expect(store.errorMessage, 'Products could not be loaded');
    expect(store.hasUnlocked51To100, isFalse);
  });

  test(
    'concurrent retries share initialization and retain one listener',
    () async {
      platform.availability = Completer<bool>();
      final first = store.initialize();
      final second = store.initialize();
      expect(identical(first, second), isTrue);
      platform.availability!.complete(true);
      await Future.wait([first, second]);
      expect(platform.queryCalls, 2);
      var events = 0;
      store.addListener(() => events++);
      platform.updates.add([purchaseUpdate(PurchaseStatus.pending)]);
      await Future<void>.delayed(Duration.zero);
      expect(events, 1);
    },
  );

  test('failed purchase starts clear pending and expose an error', () async {
    platform.purchaseStarted = false;
    expect(await store.purchaseProduct(testProduct()), isFalse);
    expect(store.storeEvent, StoreEvent.error);
    expect(store.errorMessage, contains('could not be started'));
    platform.purchaseError = StateError('Payment service unavailable');
    expect(await store.purchaseProduct(testProduct()), isFalse);
    expect(store.storeEvent, StoreEvent.error);
    expect(store.errorMessage, contains('Payment service unavailable'));
    expect(store.hasUnlocked51To100, isFalse);
  });

  test(
    'purchase becomes pending immediately and duplicate taps are ignored',
    () async {
      expect(await store.purchaseProduct(testProduct()), isTrue);
      expect(store.storeEvent, StoreEvent.purchasePending);
      expect(await store.purchaseProduct(testProduct()), isFalse);
      expect(platform.purchaseCalls, 1);
    },
  );

  test('restore gives honest feedback and exposes failures', () async {
    await store.restorePurchases();
    expect(platform.restoreCalls, 1);
    expect(store.isRestoring, isFalse);
    expect(store.hasUnlocked51To100, isFalse);
    expect(store.statusMessage, contains('Restore requested'));
    platform.restoreError = StateError('Restore unavailable');
    await store.restorePurchases();
    expect(store.storeEvent, StoreEvent.error);
    expect(store.errorMessage, contains('Restore unavailable'));
    expect(store.statusMessage, isNull);
    expect(store.isRestoring, isFalse);
  });

  test(
    'transaction completion errors are surfaced without losing the purchase',
    () async {
      platform.completionError = StateError('Completion unavailable');
      platform.updates.add([
        purchaseUpdate(PurchaseStatus.purchased)
          ..pendingCompletePurchase = true,
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(store.hasUnlocked51To100, isTrue);
      expect(store.storeEvent, StoreEvent.error);
      expect(store.errorMessage, contains('Completion unavailable'));
    },
  );

  test(
    'disposing during initialization does not notify disposed listeners',
    () async {
      platform.availability = Completer<bool>();
      final pending = store.initialize();
      store.dispose();
      platform.availability!.complete(true);
      await pending;
      store = GameStore();
    },
  );
}
