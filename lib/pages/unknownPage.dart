import 'package:flutter/material.dart';

class UnknownPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Invalid Page")),
        body: SafeArea(child: Center(child: Text("Unknown page"))));
  }
}
