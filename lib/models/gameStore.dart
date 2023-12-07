import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

enum StoreEvent { loading, ready, unavailable, purchasePending, error }

class GameStore extends ChangeNotifier {
  static final String productUnlock51to100 =
      'anagramladder.levels_51to100.difficulty_all';
  static final List<String> productIds = <String>[productUnlock51to100];

  InAppPurchase get _inAppPurchase => InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  List<PurchaseDetails> purchases = [];
  List<String> notFoundIds = [];
  List<ProductDetails> products = [];
  bool isAvailable = false;
  String? errorMessage;
  StoreEvent storeEvent = StoreEvent.loading;

  bool get isLoaded => storeEvent != StoreEvent.loading;
  bool get hasUnlocked51To100 =>
      purchases.any((element) => element.productID == productUnlock51to100);

  Future initialize() async {
    print("gameStore: Start initialize");
    if (defaultTargetPlatform == TargetPlatform.android) {
      storeEvent = StoreEvent.error;
      return;
    }

    try {
      final Stream<List<PurchaseDetails>> purchaseUpdated =
          _inAppPurchase.purchaseStream;
      _subscription = purchaseUpdated.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        _subscription.cancel();
      }, onError: (error) {
        print("gameStore: Listen error -> $error");
      });

      await initStoreInfo();
    } catch (err) {
      print("gameStore: Store initialize error -> $err");
      storeEvent = StoreEvent.error;
      notifyListeners();
    } finally {
      if (storeEvent == StoreEvent.loading) {
        storeEvent = StoreEvent.ready;
      }
      notifyListeners();
      print("gameStore: End initialize");
    }
  }

  Future<void> initStoreInfo() async {
    isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      storeEvent = StoreEvent.unavailable;
      notifyListeners();
      return;
    }

    ProductDetailsResponse productDetailResponse =
        await _inAppPurchase.queryProductDetails(productIds.toSet());

    products = productDetailResponse.productDetails;
    notFoundIds = productDetailResponse.notFoundIDs;

    if (productDetailResponse.error != null) {
      print(
          "gameStore: Error querying: ${productDetailResponse.error!.message}");
      errorMessage = productDetailResponse.error!.message;
      storeEvent = StoreEvent.ready;
      notifyListeners();
      return;
    } else {
      errorMessage = null;
    }

    if (productDetailResponse.productDetails.isNotEmpty) {
      print("gameStore: Restoring past purchases");
      await _inAppPurchase.restorePurchases();
    }

    storeEvent = StoreEvent.ready;
    notifyListeners();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    print("gameStore: Event -> Listener called");
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        storeEvent = StoreEvent.purchasePending;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          print("gameStore: Event -> Purchase error");
          storeEvent = StoreEvent.error;
          errorMessage = purchaseDetails.error!.message;
          notifyListeners();
        } else if (purchaseDetails.status == PurchaseStatus.purchased) {
          print("gameStore: Event -> Recording purchased item");
          errorMessage = null;
          _addToPurchases(purchaseDetails);
          storeEvent = StoreEvent.ready;
          notifyListeners();
        }

        if (purchaseDetails.pendingCompletePurchase &&
            (purchaseDetails.status == PurchaseStatus.restored ||
                purchaseDetails.status == PurchaseStatus.purchased)) {
          print("gameStore: Event -> Completing pending purchase");
          errorMessage = null;
          storeEvent = StoreEvent.ready;
          _addToPurchases(purchaseDetails);
          notifyListeners();
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    });
  }

  void _addToPurchases(PurchaseDetails purchaseDetails) {
    if (purchases.any((x) => x.productID == purchaseDetails.productID)) {
      return;
    }

    purchases.add(purchaseDetails);
  }

  Future<bool> purchaseProduct(ProductDetails productDetails) async {
    PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
      applicationUserName: null,
    );

    return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> completePendingPurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }
  }
}
