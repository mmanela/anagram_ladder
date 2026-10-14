import 'dart:math';

import 'package:flutter/material.dart';

class LetterBoxDimensions {
  static const MaxBoardWidth = 700;
  static const horizontalPadding = 8.0;
  late double boxWidth;
  late double boxHeight;
  late double boxRatio;
  late double boxFontSize = 30;
  late double maxLetterBoxWidth;
  late double screenWidth;
  late double screenHeight;
  final double outerPadding = horizontalPadding * 2;
  final double activeInfoBuffer = 50;
  late double effectiveMaxWidth;
  bool scrollNeeded = false;
  late TextScaler textScaler;

  LetterBoxDimensions(
    BuildContext context,
    int letterCount,
    int rungs, {
    double? availableWidth,
  }) {
    final media = MediaQuery.of(context);
    final deviceSize = media.size;
    textScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25);
    screenHeight = deviceSize.height;
    screenWidth = deviceSize.width;
    effectiveMaxWidth = min(
      availableWidth ??
          deviceSize.width - media.padding.horizontal - outerPadding,
      MaxBoardWidth.toDouble(),
    );
    boxWidth = min(effectiveMaxWidth / letterCount, 72);
    boxRatio = media.orientation == Orientation.portrait
        ? 7.0 / 5.0
        : 6.0 / 7.0;
    boxHeight = max(48, boxWidth * boxRatio);
    maxLetterBoxWidth = boxWidth * letterCount;
    scrollNeeded =
        boxHeight * rungs + activeInfoBuffer + boxHeight > screenHeight;
  }
}
