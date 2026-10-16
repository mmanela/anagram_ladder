import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/pages/loadingPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class LoadingGameState extends GameState {
  LoadingGameState(super.gameStore);

  int initializationCount = 0;

  @override
  Future<void> initialize({bool force = false}) async {
    initializationCount++;
  }
}

void main() {
  Future<LoadingGameState> showLoading(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = GameStore();
    final game = LoadingGameState(store);
    addTearDown(store.dispose);
    addTearDown(game.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<GameState>.value(
        value: game,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reducedMotion,
            ),
            child: LoadingPage(),
          ),
        ),
      ),
    );
    return game;
  }

  testWidgets('loading uses the modern badge and initializes only once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final game = await showLoading(tester);
    expect(find.text('Anagram Ladder'), findsOneWidget);
    expect(find.text('Rearrange. Solve. Climb.'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading puzzles'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/app_icon.png');
    expect(tester.getSize(find.byType(Image)), const Size(120, 120));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFFFAF8F4),
    );
    expect(game.initializationCount, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(game.initializationCount, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('reduced motion stops the loading indicator animation', (
    tester,
  ) async {
    await showLoading(tester, reducedMotion: true);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      1,
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(568, 250)]) {
    testWidgets('loading supports large text at $size', (tester) async {
      await showLoading(tester, size: size, textScale: 3, reducedMotion: true);
      await tester.ensureVisible(find.text('Loading puzzles'));
      await tester.pumpAndSettle();
      expect(find.text('Loading puzzles').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
