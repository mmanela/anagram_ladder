import 'dart:math';

import 'package:anagram_ladder/models/gameStore.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

class PayPage extends StatefulWidget {
  @override
  _PayPageState createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  late GameStore _store;
  String? _lastError;

  @override
  void initState() {
    _store = context.read<GameStore>();
    _store.addListener(_handleEvent);
    super.initState();
  }

  @override
  void dispose() {
    _store.removeListener(_handleEvent);
    super.dispose();
  }

  void _handleEvent() {
    if (_store.errorMessage != null && _lastError != _store.errorMessage) {
      _lastError = _store.errorMessage;
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      //   content: Text(_store.errorMessage!),
      // ));
      print("PayPage: ${_store.errorMessage!}");
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stack = [];

    stack.add(
      ListView(
        children: [_buildConnectionCheckTile(), _buildProductList()],
      ),
    );

    if (_store.storeEvent == StoreEvent.purchasePending) {
      stack.add(
        Stack(
          children: [
            Opacity(
              opacity: 0.3,
              child: const ModalBarrier(dismissible: false, color: Colors.grey),
            ),
            Center(
              child: CircularProgressIndicator(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
        appBar: AppBar(title: Text("Store")),
        body: SafeArea(
          child: Stack(
            children: stack,
          ),
        ));
  }

  Card _buildConnectionCheckTile() {
    final textScaleFactor = min(1.4, MediaQuery.of(context).textScaleFactor);
    if (!_store.isLoaded) {
      return Card(
          child: ListTile(
              title: Text('Trying to connect...',
                  textScaleFactor: textScaleFactor)));
    }
    final List<Widget> children = <Widget>[];

    if (!_store.isAvailable) {
      children.addAll([
        Divider(),
        ListTile(
          title: Text('Not connected',
              style: TextStyle(color: ThemeData.light().colorScheme.error),
              textScaleFactor: textScaleFactor),
          subtitle: Text('Unable to connect to the store!',
              textScaleFactor: textScaleFactor),
        ),
      ]);
    }
    return Card(child: Column(children: children));
  }

  Card _buildProductList() {
    final textScaleFactor = min(1.4, MediaQuery.of(context).textScaleFactor);
    if (!_store.isLoaded) {
      return Card(
          child: (ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Fetching products...',
                  textScaleFactor: textScaleFactor))));
    }
    if (!_store.isAvailable) {
      return Card();
    }
    List<ListTile> productList = <ListTile>[];
    if (_store.notFoundIds.isNotEmpty) {
      productList.add(ListTile(
          title: Text('[${_store.notFoundIds.join(", ")}] not found',
              style: TextStyle(
                color: ThemeData.light().colorScheme.error,
              ),
              textScaleFactor: textScaleFactor),
          subtitle: Text('Failed to find products.',
              textScaleFactor: textScaleFactor)));
    }

    Map<String, PurchaseDetails> purchases =
        Map.fromEntries(_store.purchases.map((PurchaseDetails purchase) {
      _store.completePendingPurchase(purchase);
      return MapEntry<String, PurchaseDetails>(purchase.productID, purchase);
    }));
    productList.addAll(_store.products.map(
      (ProductDetails productDetails) {
        PurchaseDetails? previousPurchase = purchases[productDetails.id];
        String title = productDetails.description.isEmpty
            ? productDetails.title
            : productDetails.description;
        title = title.isEmpty
            ? "Unlock levels 51 to 100 in all difficulties"
            : title;
        return ListTile(
            title: Text(title, textScaleFactor: textScaleFactor),
            trailing: previousPurchase != null
                ? Icon(Icons.check)
                : TextButton(
                    child: Text(productDetails.price,
                        textScaleFactor: textScaleFactor),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Colors.green[800],
                    ),
                    onPressed: () {
                      _store.purchaseProduct(productDetails);
                    },
                  ));
      },
    ));

    return Card(
        margin: EdgeInsets.fromLTRB(10, 20, 10, 0),
        child: Column(children: productList));
  }
}
