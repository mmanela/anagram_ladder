import 'package:anagram_ladder/utils/screen.dart';
import 'package:flutter/material.dart';

class GameMenuButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const GameMenuButton(
      {Key? key, required this.child, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final minHeight = isBigScreen(context) ? 75.0 : 55.0;
    return ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: 275, minWidth: 215, minHeight: minHeight),
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10)),
            onPressed: onPressed,
            child: child));
  }
}
