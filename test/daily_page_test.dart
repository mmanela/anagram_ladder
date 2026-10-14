import 'dart:convert';

import 'package:anagram_ladder/anagram/ladderLevel.dart';
import 'package:anagram_ladder/components/dailyResultCard.dart';
import 'package:anagram_ladder/components/rungTransition.dart';
import 'package:anagram_ladder/models/dailyChallenge.dart';
import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:anagram_ladder/models/levelState.dart';
import 'package:anagram_ladder/navigation/gameRouteNavigator.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:anagram_ladder/navigation/gameRouteInformationParser.dart';
import 'package:anagram_ladder/navigation/gameRouterDelegate.dart';
import 'package:anagram_ladder/pages/homePage.dart';
import 'package:anagram_ladder/pages/levelPage.dart';
import 'package:anagram_ladder/pages/unknownPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'level_page_test.dart' show setViewport, expectVisibleActiveLetters;
import 'widget_test.dart' show startGame;

Future<GameState> startDailyAt(
  WidgetTester tester,
  DateTime date, {
  DateTime Function()? clock,
  GameRoutePath? initialRoute,
}) async {
  final store = GameStore();
  final game = GameState(store, now: clock ?? () => date);
  final navigation = GameRouteNavigator();
  final router = GameRouterDelegate(navigation, game, store);
  addTearDown(store.dispose);
  addTearDown(game.dispose);
  addTearDown(navigation.dispose);
  addTearDown(router.dispose);
  final routeInformationProvider = initialRoute == null
      ? null
      : PlatformRouteInformationProvider(
          initialRouteInformation: GameRouteInformationParser()
              .restoreRouteInformation(initialRoute)!,
        );
  if (routeInformationProvider != null) {
    addTearDown(routeInformationProvider.dispose);
  }
  if (initialRoute != null) navigation.goto(initialRoute);
  await tester.runAsync(() => game.initialize());
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: game),
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: navigation),
      ],
      child: MaterialApp.router(
        routeInformationProvider: routeInformationProvider,
        routerDelegate: router,
        routeInformationParser: GameRouteInformationParser(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return game;
}

Future<void> showDaily(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Daily ladder'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Daily ladder'));
  await tester.pumpAndSettle();
  expect(find.byType(LevelPage), findsOneWidget);
}

Future<LadderLevel> seedDailyFinal(
  GameState game,
  DailyChallenge day, {
  bool completed = false,
}) async {
  final ladder = await game.getLevelOrLoad(day.world, day.level);
  final rungs = ladder.getBottomUp();
  final solution = ladder.words.firstWhere(
    (word) => !ladder.words.contains(word.substring(1) + word[0]),
  );
  await game.persistDailyState(
    day,
    LevelState(
      day.world,
      day.level,
      completed ? ladder.letterCount : rungs[rungs.length - 2].letterCount,
      completed ? rungs.length : rungs.length - 1,
      rungs.length,
      [
        for (final rung in rungs.take(rungs.length - 1))
          rung.words.first.split(''),
        (completed ? solution : solution.substring(1) + solution[0]).split(''),
      ],
    ),
  );
  return ladder;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final wasFatal = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = wasFatal);
  });

  for (final world in GameState.worldIds) {
    testWidgets('difficulty $world is clear before play and in the result', (
      tester,
    ) async {
      setViewport(tester, const Size(400, 800));
      final date = [
        for (var offset = 0; offset < DailyChallenge.puzzleCount; offset++)
          DateTime(2026, 10, 14 + offset),
      ].firstWhere((date) => DailyChallenge(date).world == world);
      final game = await startDailyAt(tester, date);
      final day = game.today;
      expect(find.text('${day.difficultyDescription}.'), findsOneWidget);
      await showDaily(tester);
      expect(tester.widget<LevelPage>(find.byType(LevelPage)).world, world);
      expect(game.getDailyState(day).world, world);
      final progress = game.getDailyState(day);
      expectVisibleActiveLetters(
        tester,
        progress.levelLetters[progress.currentRung],
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      final ladder = await seedDailyFinal(game, day, completed: true);
      await tester.pumpAndSettle();
      await showDaily(tester);
      expect(find.byType(DailyResultCard), findsOneWidget);
      expect(find.text(day.difficultyDescription), findsOneWidget);
      expect(
        day.shareText(
          ladder.getBottomUp().map((rung) => rung.letterCount).toList(),
        ),
        contains('${day.difficulty} |'),
      );
    });
  }

  for (final initialLink in [false, true]) {
    testWidgets('/daily opens directly and pins the date across midnight '
        '(initial link: $initialLink)', (tester) async {
      setViewport(tester, const Size(400, 800));
      var now = DateTime(2026, 10, 14, 12);
      final game = await startDailyAt(
        tester,
        now,
        clock: () => now,
        initialRoute: initialLink ? GameRoutePath.daily() : null,
      );
      if (!initialLink) {
        tester
            .element(find.text('Play'))
            .read<GameRouteNavigator>()
            .goto(GameRoutePath.daily());
        await tester.pumpAndSettle();
      }
      final navigation = tester
          .element(find.byType(LevelPage))
          .read<GameRouteNavigator>();
      expect(navigation.current.page, GameRoutePage.DailyLevel);
      expect(navigation.current.dailyDate, '2026-10-14');
      now = DateTime(2026, 10, 15, 12);
      await tester.runAsync(() async {
        game.didChangeAppLifecycleState(AppLifecycleState.resumed);
      });
      await tester.pumpAndSettle();
      expect(game.today.dateKey, '2026-10-15');
      expect(
        tester.widget<LevelPage>(find.byType(LevelPage)).daily!.dateKey,
        '2026-10-14',
      );
      expect(navigation.current.dailyDate, '2026-10-14');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      await showDaily(tester);
      expect(
        tester.widget<LevelPage>(find.byType(LevelPage)).daily!.dateKey,
        '2026-10-15',
      );
    });
  }

  testWidgets('old dated links resume their original Normal puzzle', (
    tester,
  ) async {
    setViewport(tester, const Size(400, 800));
    final date = DateTime(2026, 10, 14);
    final game = await startDailyAt(tester, date);
    final old = DailyChallenge.legacy(date);
    final ladder = await game.getLevelOrLoad(old.world, old.level);
    final progress = LevelState(
      old.world,
      old.level,
      0,
      0,
      ladder.getBottomUp().length,
      [
        ladder.getBottom().letters.reversed.toList(),
        for (final rung in ladder.getBottomUp().skip(1))
          List.filled(rung.letterCount, ''),
      ],
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'daily_v1_progress_${old.dateKey}',
      jsonEncode(progress.toJson()),
    );
    tester
        .element(find.text('Play'))
        .read<GameRouteNavigator>()
        .goto(GameRoutePath.dailyLevel(old.dateKey));
    await tester.pumpAndSettle();
    final page = tester.widget<LevelPage>(find.byType(LevelPage));
    expect(page.world, old.world);
    expect(page.level, old.level);
    expect(page.daily!.isLegacy, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one tap opens daily progress and Back returns directly home', (
    tester,
  ) async {
    setViewport(tester, const Size(400, 800));
    await startGame(tester);
    final context = tester.element(find.text('Play'));
    final game = context.read<GameState>();
    final navigation = context.read<GameRouteNavigator>();
    await showDaily(tester);
    expect(find.byType(LevelPage), findsOneWidget);
    final day = game.today;
    final letters = List<String>.of(game.getDailyState(day).levelLetters.first);
    final bottom = (await game.getLevelOrLoad(
      day.world,
      day.level,
    )).getBottom();
    final move =
        [
          for (var from = 0; from < letters.length; from++)
            for (var to = 0; to < letters.length; to++)
              if (from != to) (from: from, to: to),
        ].firstWhere((move) {
          final moved = List.of(letters);
          moved.insert(move.to, moved.removeAt(move.from));
          return moved.join() != letters.join() &&
              !bottom.words.contains(moved.join());
        });
    final expected = List.of(letters);
    expected.insert(move.to, expected.removeAt(move.from));
    final reorder = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    reorder.onReorderItem!(move.from, move.to);
    await tester.pumpAndSettle();
    final saved = game.getDailyState(day).levelLetters.first;
    expect(saved, expected);
    expect(game.getLevelState(day.world, day.level).isEmpty, isTrue);
    expect(game.resumeLevel, isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(navigation.current.page, GameRoutePage.Home);
    await showDaily(tester);
    expect(game.getDailyState(day).levelLetters.first, saved);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('leaving during the letter drop preserves daily progress', (
    tester,
  ) async {
    setViewport(tester, const Size(400, 800));
    final game = await startDailyAt(tester, DateTime(2026, 10, 15));
    final day = game.today;
    final ladder = await game.getLevelOrLoad(day.world, day.level);
    final rungs = ladder.getBottomUp();
    final solution = rungs.first.words.firstWhere(
      (word) => !rungs.first.words.contains(word.substring(1) + word[0]),
    );
    await game.persistDailyState(
      day,
      LevelState(day.world, day.level, 0, 0, rungs.length, [
        (solution.substring(1) + solution[0]).split(''),
        for (final rung in rungs.skip(1)) List.filled(rung.letterCount, ''),
      ]),
    );
    await showDaily(tester);
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(solution.length - 1, 0);
    await tester.pump(LevelPage.solveDuration);
    await tester.pump();
    expect(find.byType(RungTransition), findsOneWidget);
    expect(game.getDailyState(day).currentRung, 1);
    expect(game.getDailyState(day).levelLetters.first.join(), solution);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(game.getDailyState(day).currentRung, 1);
    await showDaily(tester);
    expect(game.getDailyState(day).currentRung, greaterThanOrEqualTo(1));
    expect(game.getDailyState(day).levelLetters.first.join(), solution);
    expect(game.getLevelState(day.world, day.level).isEmpty, isTrue);
    expect(game.resumeLevel, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily completion is remembered and replay keeps credit', (
    tester,
  ) async {
    setViewport(tester, const Size(400, 800));
    final semantics = tester.ensureSemantics();
    try {
      await startGame(tester);
      final context = tester.element(find.text('Play'));
      final game = context.read<GameState>();
      final navigation = context.read<GameRouteNavigator>();
      final day = game.today;
      final ladder = await seedDailyFinal(game, day);
      navigation.goto(GameRoutePath.dailyLevel(day.dateKey));
      await tester.pumpAndSettle();
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(ladder.letterCount - 1, 0);
      await tester.pumpAndSettle();
      expect(find.byType(DailyResultCard), findsOneWidget);
      expect(game.isDailyCompleted(day), isTrue);
      expect(game.getWorldCompletionInfo(day.world).completedCount, 0);
      await tester.ensureVisible(find.text('Replay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replay'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyResultCard), findsNothing);
      expect(game.getDailyState(day).currentRung, 0);
      expect(game.isDailyCompleted(day), isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.textContaining('Completed today'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('future and unplayed past daily links cannot unlock puzzles', (
    tester,
  ) async {
    await startGame(tester);
    final context = tester.element(find.text('Play'));
    final game = context.read<GameState>();
    final navigation = context.read<GameRouteNavigator>();
    for (final offset in [-1, 1]) {
      final date = DailyChallenge(game.today.date.add(Duration(days: offset)));
      navigation.goto(GameRoutePath.dailyLevel(date.dateKey));
      await tester.pumpAndSettle();
      expect(find.byType(UnknownPage), findsOneWidget);
      expect(find.byType(LevelPage), findsNothing);
    }
  });

  testWidgets('invalid daily progress is reported without overwriting it', (
    tester,
  ) async {
    await startGame(tester);
    final context = tester.element(find.text('Play'));
    final game = context.read<GameState>();
    final prefs = await SharedPreferences.getInstance();
    final key = 'daily_v2_progress_${game.today.dateKey}';
    await prefs.setString(key, '{"invalid":true}');
    await showDaily(tester);
    expect(
      find.text('Could not load this ladder. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(prefs.getString(key), '{"invalid":true}');
    expect(tester.takeException(), isNull);
  });

  for (final (size, scale) in [
    (const Size(320, 568), 3.0),
    (const Size(568, 320), 1.0),
  ]) {
    testWidgets('direct daily result and home fit $size at ${scale}x text', (
      tester,
    ) async {
      setViewport(tester, size, textScale: scale);
      await startGame(tester);
      final context = tester.element(find.text('Play'));
      final game = context.read<GameState>();
      await seedDailyFinal(game, game.today, completed: true);
      context.read<GameRouteNavigator>().goto(GameRoutePath.daily());
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing);
      expect(find.byTooltip('Previous month'), findsNothing);
      expect(find.textContaining('free Normal ladder'), findsNothing);
      expect(find.byType(DailyResultCard), findsOneWidget);
      await tester.ensureVisible(find.text('Share result'));
      await tester.pumpAndSettle();
      expect(find.text('Share result').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('Back to home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'sharing and copying use spoiler-free results and an iPad anchor',
    (tester) async {
      final calls = <MethodCall>[];
      const share = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(share, (
        call,
      ) async {
        calls.add(call);
        return 'test.activity';
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') calls.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          share,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final day = DailyChallenge(DateTime(2026, 10, 14));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DailyResultCard(
                challenge: day,
                wordLengths: const [4, 5, 6],
                onReplay: () {},
                onBack: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Share result'));
      await tester.pumpAndSettle();
      final shared = calls.singleWhere((call) => call.method == 'share');
      expect(shared.arguments['text'], day.shareText([4, 5, 6]));
      expect(shared.arguments['originWidth'], greaterThan(0));
      expect(shared.arguments['originHeight'], greaterThan(0));
      await tester.tap(find.text('Copy result'));
      await tester.pumpAndSettle();
      final copied = calls.singleWhere(
        (call) => call.method == 'Clipboard.setData',
      );
      expect(copied.arguments['text'], shared.arguments['text']);
      expect(find.text('Result copied'), findsOneWidget);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        share,
        (_) async => throw PlatformException(code: 'share-failed'),
      );
      await tester.tap(find.text('Share result'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not share. You can copy the result instead.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
