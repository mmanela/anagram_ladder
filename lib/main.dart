import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/navigation/gameRouteInformationParser.dart';
import 'package:anagram_ladder/navigation/gameRouterDelegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/gameStore.dart';
import 'navigation/gameRouteNavigator.dart';

void main() {
  // Disabling for now since google store forces address publication
  // if (defaultTargetPlatform == TargetPlatform.android) {
  //   InAppPurchaseAndroidPlatformAddition.enablePendingPurchases();
  // }

  WidgetsFlutterBinding.ensureInitialized();
  runApp(AnagramLadderApp());
}

class AnagramLadderApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _AnagramLadderAppState();
}

class _AnagramLadderAppState extends State<AnagramLadderApp> {
  GameRouteNavigator _navigator = GameRouteNavigator();
  GameRouterDelegate? _routerDelegate;
  GameRouteInformationParser _routeInformationParser =
      GameRouteInformationParser();
  late GameStore _gameStore;
  late GameState _gameState;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _gameStore = GameStore();
    _gameStore.initialize();
    _gameState = GameState(_gameStore);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);
    _routerDelegate = GameRouterDelegate(_navigator, _gameState, _gameStore);
  }

  final _theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      pageTransitionsTheme: PageTransitionsTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(textStyle: TextStyle(fontSize: 25))),
      appBarTheme:
          AppBarTheme(color: Colors.deepPurple, foregroundColor: Colors.white),
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple));

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _navigator),
          ChangeNotifierProvider.value(value: _gameStore),
          ChangeNotifierProvider.value(value: _gameState),
        ],
        child: MaterialApp.router(
          title: 'Anagram Ladder',
          theme: _theme,
          debugShowCheckedModeBanner: false,
          routerDelegate: _routerDelegate!,
          routeInformationParser: _routeInformationParser,
        ));
  }
}
