import 'dart:math';

import 'package:flutter/material.dart';

class LetterBoxDimensions {
  static const MaxBoardWidth = 700;
  late double boxWidth;
  late double boxHeight;
  late double boxRatio;
  late double boxFontSize = 30;
  late double maxLetterBoxWidth;
  late double screenWidth;
  late double screenHeight;
  final double outerPadding = 20;
  final double activeInfoBuffer = 50;
  late double effectiveMaxWidth;
  bool scrollNeeded = false;
  late double textScaleFactor;

  LetterBoxDimensions(BuildContext context, int world, int rungs) {
    // Calculate width for device size
    final media = MediaQuery.of(context);
    final deviceSize = media.size;
    textScaleFactor = min(1.25, MediaQuery.of(context).textScaleFactor);
    screenHeight = deviceSize.height;
    screenWidth = deviceSize.width;
    effectiveMaxWidth = min(deviceSize.width, MaxBoardWidth) -
        outerPadding -
        (media.padding.right + media.padding.left);
    boxWidth = effectiveMaxWidth / world;
    boxRatio =
        media.orientation == Orientation.portrait ? 7.0 / 5.0 : 6.0 / 7.0;
    boxHeight = boxWidth * boxRatio;
    maxLetterBoxWidth = boxWidth * world;
    scrollNeeded =
        boxHeight * rungs + activeInfoBuffer + boxHeight > screenHeight;
  }
}
