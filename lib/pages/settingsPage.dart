import 'dart:math';

import 'package:anagram_ladder/components/gameMenuButton.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/utils/screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage();

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _versionText = "";

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      String appName = packageInfo.appName;
      String version = packageInfo.version;
      String buildNumber = packageInfo.buildNumber;
      setState(() {
        _versionText = "$appName v$version+$buildNumber";
      });
    });
  }

  static const String feedbackEmailUrl =
      "mailto:AnagramLadder@gmail.com?subject=Feedback";
  Widget _resetButton(BuildContext context) {
    final textScaleFactor = min(1.2, MediaQuery.of(context).textScaleFactor);
    return Container(
        padding: EdgeInsets.only(bottom: 0),
        child: GameMenuButton(
            onPressed: () {
              _showClearDataDialog();
            },
            child: Text("Reset Game", textScaleFactor: textScaleFactor)));
  }

  Widget _sendFeedbackButton(BuildContext context) {
    final textScaleFactor = min(1.2, MediaQuery.of(context).textScaleFactor);
    return Container(
        padding: EdgeInsets.only(bottom: 0),
        child: GameMenuButton(
            onPressed: () async {
              await launchUrl(Uri.parse(feedbackEmailUrl));
            },
            child: Text("Send Feedback", textScaleFactor: textScaleFactor)));
  }

  Widget _versionInfo(BuildContext context) {
    final textScaleFactor = min(1.4, MediaQuery.of(context).textScaleFactor);
    return Container(
        padding: EdgeInsets.fromLTRB(0, 10, 0, 10),
        child: Text(
          _versionText,
          textScaleFactor: textScaleFactor,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Settings")),
        body: SafeArea(
            child: Column(children: [
          Center(child: _versionInfo(context)),
          Expanded(
              child: Container(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                  alignment: Alignment.topCenter,
                  child: _gridView(context))),
        ])));
  }

  Widget _gridView(BuildContext context) {
    final isPortrait = shouldTreatAsPortrait(context);
    return GridView.count(
      crossAxisCount: isPortrait ? 1 : 2,
      children: <Widget>[
        Center(child: _resetButton(context)),
        Center(child: _sendFeedbackButton(context))
      ],
      childAspectRatio: 3,
      padding: EdgeInsets.zero,
    );
  }

  Future<void> _showClearDataDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final textScaleFactor =
            min(1.4, MediaQuery.of(context).textScaleFactor);
        return AlertDialog(
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Warning!',
                    textScaleFactor: textScaleFactor,
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 30)),
                Text('Are you sure you want to reset all game data?',
                    textScaleFactor: textScaleFactor),
              ],
            ),
          ),
          actions: <Widget>[
            OutlinedButton(
                child: Text('Cancel',
                    textScaleFactor: textScaleFactor,
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(context).pop();
                }),
            SizedBox(width: 5),
            OutlinedButton(
              style: OutlinedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Yes, I am sure',
                  textScaleFactor: textScaleFactor,
                  style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final gameState = context.read<GameState>();
                await gameState.reset();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Game data reset'),
                ));
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
