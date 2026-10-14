import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum StoreEvent { loading, ready, unavailable, purchasePending, error }

class GameStore extends ChangeNotifier {
  static final String productUnlock51to100 =
      'anagramladder.levels_51to100.difficulty_all';
  static final List<String> productIds = <String>[productUnlock51to100];

  InAppPurchase get _inAppPurchase => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void>? _initialization;
  bool _disposed = false;

  List<PurchaseDetails> purchases = [];
  List<String> notFoundIds = [];
  List<ProductDetails> products = [];
  bool isAvailable = false;
  String? errorMessage;
  String? statusMessage;
  bool isRestoring = false;
  StoreEvent storeEvent = StoreEvent.loading;

  bool get isLoaded => storeEvent != StoreEvent.loading;
  bool get isBusy =>
      !isLoaded || storeEvent == StoreEvent.purchasePending || isRestoring;
  bool get hasUnlocked51To100 =>
      purchases.any((element) => element.productID == productUnlock51to100);

  Future<void> initialize() {
    if (_disposed) throw StateError('Store has been disposed');
    return _initialization ??= _initialize().whenComplete(
      () => _initialization = null,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _reportError(Object error) {
    debugPrint('gameStore: $error');
    errorMessage = error.toString();
    statusMessage = null;
    storeEvent = StoreEvent.error;
    _notify();
  }

  Future<void> _initialize() async {
    if (storeEvent == StoreEvent.purchasePending || isRestoring) return;
    storeEvent = StoreEvent.loading;
    errorMessage = null;
    statusMessage = null;
    _notify();
    if (defaultTargetPlatform == TargetPlatform.android) {
      isAvailable = false;
      storeEvent = StoreEvent.unavailable;
      _notify();
      return;
    }

    try {
      _subscription ??= _inAppPurchase.purchaseStream.listen(
        (purchaseDetailsList) {
          unawaited(_listenToPurchaseUpdated(purchaseDetailsList));
        },
        onDone: () {
          _subscription = null;
          _reportError('The store connection closed. Please retry.');
        },
        onError: _reportError,
      );

      await initStoreInfo();
    } catch (err) {
      _reportError(err);
    }
  }

  Future<void> initStoreInfo() async {
    isAvailable = await _inAppPurchase.isAvailable();
    if (_disposed) return;
    if (!isAvailable) {
      storeEvent = StoreEvent.unavailable;
      _notify();
      return;
    }

    ProductDetailsResponse productDetailResponse = await _inAppPurchase
        .queryProductDetails(productIds.toSet());
    if (_disposed) return;

    products = productDetailResponse.productDetails;
    notFoundIds = productDetailResponse.notFoundIDs;

    if (productDetailResponse.error != null) {
      _reportError(productDetailResponse.error!.message);
      return;
    } else {
      errorMessage = null;
    }

    if (productDetailResponse.productDetails.isNotEmpty) {
      await _inAppPurchase.restorePurchases();
      if (_disposed) return;
    }

    if (storeEvent == StoreEvent.loading) {
      storeEvent = StoreEvent.ready;
    }
    _notify();
  }

  Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (_disposed) return;
      if (purchaseDetails.status == PurchaseStatus.pending) {
        errorMessage = null;
        statusMessage = null;
        storeEvent = StoreEvent.purchasePending;
        _notify();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _reportError(
            purchaseDetails.error?.message ?? 'The purchase failed.',
          );
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          errorMessage = null;
          statusMessage = 'Purchase canceled.';
          storeEvent = StoreEvent.ready;
          _notify();
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          errorMessage = null;
          statusMessage = 'Your extra ladders are unlocked.';
          _addToPurchases(purchaseDetails);
          storeEvent = StoreEvent.ready;
          _notify();
        }

        if (purchaseDetails.pendingCompletePurchase &&
            (purchaseDetails.status == PurchaseStatus.restored ||
                purchaseDetails.status == PurchaseStatus.purchased)) {
          await completePendingPurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> restorePurchases() async {
    if (isBusy || !isAvailable) return;
    isRestoring = true;
    errorMessage = null;
    statusMessage = null;
    _notify();
    try {
      await _inAppPurchase.restorePurchases();
      statusMessage = hasUnlocked51To100
          ? 'Your extra ladders are unlocked.'
          : 'Restore requested. Any purchases found will appear here.';
    } catch (error) {
      _reportError(error);
    } finally {
      isRestoring = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }

  void _addToPurchases(PurchaseDetails purchaseDetails) {
    if (purchases.any((x) => x.productID == purchaseDetails.productID)) {
      return;
    }

    purchases.add(purchaseDetails);
  }

  Future<bool> purchaseProduct(ProductDetails productDetails) async {
    if (isBusy || !isAvailable || hasUnlocked51To100) return false;
    errorMessage = null;
    statusMessage = null;
    storeEvent = StoreEvent.purchasePending;
    _notify();
    try {
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: productDetails),
      );
      if (!started) {
        _reportError('The purchase could not be started. Please try again.');
      }
      return started;
    } catch (error) {
      _reportError(error);
      return false;
    }
  }

  Future<void> completePendingPurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      try {
        await _inAppPurchase.completePurchase(purchase);
      } catch (error) {
        _reportError(error);
      }
    }
  }
}
