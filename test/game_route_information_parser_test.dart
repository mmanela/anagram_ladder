import 'package:anagram_ladder/navigation/gameRouteInformationParser.dart';
import 'package:anagram_ladder/navigation/gameRoutePath.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = GameRouteInformationParser();
  final routes = {
    '/': GameRoutePath.home(),
    '/about': GameRoutePath.about(),
    '/settings': GameRoutePath.settings(),
    '/daily': GameRoutePath.daily(),
    '/daily/2026-10-14': GameRoutePath.dailyLevel('2026-10-14'),
    '/pay': GameRoutePath.pay(),
    '/worldSet': GameRoutePath.worldSet(),
    '/world/6': GameRoutePath.world(6),
    '/world/10/level/100': GameRoutePath.level(10, 100),
  };

  for (final entry in routes.entries) {
    test('${entry.key} parses and round-trips to the same page', () async {
      final parsed = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse(entry.key)),
      );
      expect(parsed.page, entry.value.page);
      expect(parsed.world, entry.value.world);
      expect(parsed.level, entry.value.level);
      expect(parsed.dailyDate, entry.value.dailyDate);
      expect(parser.restoreRouteInformation(parsed)!.uri.path, entry.key);
    });
  }

  for (final path in [
    '/daily/not-a-date',
    '/daily/2026-02-30',
    '/daily/2026-2-1',
    '/daily/2026-10-14/extra',
    '/world',
    '/world/not-a-number',
    '/world/5',
    '/world/11',
    '/world/-1',
    '/world/6/level',
    '/world/6/level/not-a-number',
    '/world/6/level/0',
    '/world/6/level/-1',
    '/world/6/level/251',
    '/world/6/not-a-level/1',
    '/world/6/level/1/extra',
  ]) {
    test('$path is an invalid route', () async {
      final parsed = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse(path)),
      );
      expect(parsed.page, GameRoutePage.Unknown);
      expect(parser.restoreRouteInformation(parsed), isNull);
    });
  }

  test('unrecognized paths retain the existing home fallback', () async {
    final parsed = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/not-a-page')),
    );
    expect(parsed.page, GameRoutePage.Home);
  });
}
