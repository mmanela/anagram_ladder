import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/pages/aboutPage.dart';
import 'package:anagram_ladder/pages/settingsPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = 'https://matthewmanela.com/anagram-ladder-privacy-policy/';
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  late List<MethodCall> calls;
  late bool opened;
  late bool fail;

  setUp(() {
    calls = [];
    opened = true;
    fail = false;
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Anagram Ladder',
      packageName: 'com.lokshn.anagramladder',
      version: '1.2.0',
      buildNumber: '25',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (fail) throw PlatformException(code: 'unavailable');
          return opened;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Settings opens the privacy policy in an external browser', (
    tester,
  ) async {
    final store = GameStore();
    final game = GameState(store);
    addTearDown(game.dispose);
    addTearDown(store.dispose);
    await tester.runAsync(() => game.initialize());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: game,
        child: MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    final launch = calls.singleWhere((call) => call.method == 'launch');
    expect(launch.arguments['url'], url);
    expect(launch.arguments['useSafariVC'], isFalse);
    expect(
      find.text('That could not be completed. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('Settings reports a failed privacy launch', (tester) async {
    opened = false;
    final store = GameStore();
    final game = GameState(store);
    addTearDown(game.dispose);
    addTearDown(store.dispose);
    await tester.runAsync(() => game.initialize());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: game,
        child: MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(
      find.text('That could not be completed. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('About exposes the policy and reports launch exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: AboutPage()));
    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.data, contains('[privacy policy]($url)'));
    markdown.onTapLink!('privacy policy', url, '');
    await tester.pumpAndSettle();
    expect(
      calls.singleWhere((call) => call.method == 'launch').arguments['url'],
      url,
    );
    fail = true;
    markdown.onTapLink!('privacy policy', url, '');
    await tester.pumpAndSettle();
    expect(
      find.text('Could not open this link. Please try again.'),
      findsOneWidget,
    );
  });
}
