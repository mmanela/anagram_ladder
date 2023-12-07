import 'package:flutter/material.dart';

bool shouldTreatAsPortrait(BuildContext context) {
  final media = MediaQuery.of(context);
  final isPortrait = media.orientation == Orientation.portrait;
  final size = media.size;
  return isPortrait && size.width < 500;
}

bool isBigScreen(BuildContext context) {
  final media = MediaQuery.of(context);
  final size = media.size;
  return size.shortestSide > 800;
}
