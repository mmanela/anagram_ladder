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
      DeviceOrientation.landscapeRight,
    ]);
    _routerDelegate = GameRouterDelegate(_navigator, _gameState, _gameStore);
  }

  final _theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFAF8F4),
    primaryColor: const Color(0xFF6544B5),
    pageTransitionsTheme: PageTransitionsTheme(),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: const Color(0xFF292437),
      displayColor: const Color(0xFF292437),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE8E2EE)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFFAF8F4),
      foregroundColor: const Color(0xFF292437),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6544B5),
      primary: const Color(0xFF6544B5),
      surface: const Color(0xFFFAF8F4),
    ),
  );

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
      ),
    );
  }
}
