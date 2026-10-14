import 'package:anagram_ladder/components/rungTransition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('multiple added letters drop in order and land in their slots', (
    tester,
  ) async {
    const source = Rect.fromLTWH(20, 300, 288, 100);
    const target = Rect.fromLTWH(20, 100, 288, 70);
    Future<void> frame(double progress) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: RungTransition(
                  animation: AlwaysStoppedAnimation(progress),
                  from: source,
                  to: target,
                  letters: const ['s', 't', 'a', 'r', 'e', 'd'],
                  existingCount: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Finder tile(int index) => find.byKey(ValueKey('rung-flight-letter-$index'));
    double opacity(int index) => tester
        .widget<Opacity>(
          find.descendant(of: tile(index), matching: find.byType(Opacity)),
        )
        .opacity;

    await frame(0.4);
    expect(opacity(4), greaterThan(0));
    expect(opacity(5), 0);
    await frame(0.6);
    expect(opacity(4), 1);
    expect(opacity(5), 1);
    for (final index in [4, 5]) {
      final text = find.descendant(
        of: tile(index),
        matching: find.text(index == 4 ? 'e' : 'd'),
      );
      expect(text, findsOneWidget);
      expect(tester.getSize(text).isEmpty, isFalse);
    }
    await frame(1);
    for (var index = 0; index < 6; index++) {
      final rect = tester.getRect(tile(index));
      expect(rect.left, closeTo(target.left + index * 48, 0.001));
      expect(rect.top, closeTo(target.top, 0.001));
      expect(rect.size, const Size(48, 70));
      expect(opacity(index), 1);
    }
    expect(tester.takeException(), isNull);
  });
}
