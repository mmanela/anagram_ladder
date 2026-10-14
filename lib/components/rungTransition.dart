import 'dart:math';

import 'package:flutter/material.dart';

class RungTransition extends AnimatedWidget {
  static const duration = Duration(milliseconds: 560);

  final Rect from;
  final Rect to;
  final List<String> letters;
  final int existingCount;

  const RungTransition({
    super.key,
    required Animation<double> animation,
    required this.from,
    required this.to,
    required this.letters,
    required this.existingCount,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final progress = (listenable as Animation<double>).value;
    final move = const Interval(
      0,
      0.65,
      curve: Curves.easeInOutCubic,
    ).transform(progress);
    final colors = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: 1.25);
    final oldWidth = from.width / existingCount;
    final newWidth = to.width / letters.length;
    final addedCount = letters.length - existingCount;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < letters.length; index++)
              _tile(
                index,
                progress,
                move,
                oldWidth,
                newWidth,
                addedCount,
                colors,
                textScaler,
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    int index,
    double progress,
    double move,
    double oldWidth,
    double newWidth,
    int addedCount,
    ColorScheme colors,
    TextScaler textScaler,
  ) {
    final target = Rect.fromLTWH(
      to.left + index * newWidth,
      to.top,
      newWidth,
      to.height,
    );
    final added = index >= existingCount;
    var opacity = 1.0;
    late Rect rect;
    if (added) {
      final order = index - existingCount;
      final start = 0.35 + order / addedCount * 0.12;
      final end = 0.88 + (order + 1) / addedCount * 0.12;
      final drop = Interval(
        start,
        end,
        curve: Curves.easeOutBack,
      ).transform(progress);
      opacity = Interval(start, start + 0.1).transform(progress);
      rect = target.translate(0, -min(80.0, to.height) * (1 - drop));
    } else {
      final source = Rect.fromLTWH(
        from.left + index * oldWidth,
        from.top,
        oldWidth,
        from.height,
      );
      rect = Rect.lerp(source, target, move)!;
    }
    final settle = const Interval(0.75, 1).transform(progress);
    return Positioned.fromRect(
      key: ValueKey('rung-flight-letter-$index'),
      rect: rect,
      child: Opacity(
        opacity: opacity,
        child: Container(
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Color.lerp(
              added ? colors.primaryContainer : const Color(0xFF256144),
              colors.surfaceContainerLowest,
              added ? settle : move,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Color.lerp(
                added ? colors.primary : const Color(0xFF256144),
                colors.outlineVariant,
                added ? settle : move,
              )!,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                letters[index],
                textScaler: textScaler,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: added
                      ? colors.onSurface
                      : Color.lerp(Colors.white, colors.onSurface, move),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
