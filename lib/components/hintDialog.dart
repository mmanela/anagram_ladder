import 'dart:math';

import 'package:flutter/material.dart';
import 'package:more/collection.dart';

class HintDialog extends StatelessWidget {
  static Future show(BuildContext context, List<String> words, {Key? key}) =>
      showDialog(
        context: context,
        useRootNavigator: false,
        barrierDismissible: true,
        builder: (_) => HintDialog(key: key, words: words),
      ).then((res) {
        FocusScope.of(context).requestFocus(FocusNode());
        return res;
      });

  static void hide(BuildContext context) => Navigator.pop(context);

  final List<String> words;
  HintDialog({Key? key, required this.words}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: 1.25);
    final double heightBuffer = 100;
    final double heightPerRow = textScaler.scale(55);
    final totalHeight = heightPerRow * this.words.length + heightBuffer;
    final size = MediaQuery.of(context).size;
    final width = min(500.0, size.width - 50);
    final height = min(totalHeight, size.height - 100);
    return Center(
      child: Card(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height, minHeight: 0),
          child: Container(
            width: width,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(12.0),
              child: _hintDialogContents(context, textScaler),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hintDialogContents(BuildContext context, TextScaler textScaler) {
    final hints = words
        .indices()
        .map(
          (i) => WordHintControl(
            possibility: i,
            word: words[i],
            textScaler: textScaler,
          ),
        )
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            "Reveal the first and/or last letter of each of the possible words",
            textScaler: textScaler,
          ),
        ),
        const SizedBox(height: 10),
        ...hints,
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            HintDialog.hide(context);
          },
          child: Text(
            "Close",
            textScaler: textScaler,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ],
    );
  }
}

class WordHintControl extends StatefulWidget {
  final String word;
  final int possibility;
  final TextScaler textScaler;
  WordHintControl({
    Key? key,
    required this.possibility,
    required this.word,
    required this.textScaler,
  });

  @override
  State<StatefulWidget> createState() => _WordHintControlState();
}

class _WordHintControlState extends State<WordHintControl> {
  bool showFirst = false;
  bool showLast = false;

  @override
  Widget build(BuildContext context) {
    const double size = 17;
    const double labelSize = 15;
    const double letterSize = 19;
    const double rowHeight = 40;
    const style = TextStyle(fontSize: size);
    const letterStyle = TextStyle(
      fontSize: letterSize,
      fontWeight: FontWeight.bold,
    );
    return Row(
      children: [
        Text(
          "Word ${widget.possibility + 1}",
          textScaler: this.widget.textScaler,
          style: const TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 10),
        Flexible(
          child: Center(
            child: showFirst
                ? ConstrainedBox(
                    constraints: BoxConstraints(minHeight: rowHeight),
                    child: Center(
                      child: Text(
                        this.widget.word[0],
                        textScaler: this.widget.textScaler,
                        style: letterStyle,
                      ),
                    ),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(minHeight: rowHeight),
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () {
                        setState(() {
                          showFirst = true;
                        });
                      },
                      child: Text(
                        "Show first",
                        textScaler: this.widget.textScaler,
                        style: style,
                      ),
                    ),
                  ),
          ),
        ),
        Flexible(
          child: Center(
            child: showLast
                ? ConstrainedBox(
                    constraints: BoxConstraints(minHeight: rowHeight),
                    child: Center(
                      child: Text(
                        this.widget.word[this.widget.word.length - 1],
                        textScaler: this.widget.textScaler,
                        style: letterStyle,
                      ),
                    ),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(minHeight: rowHeight),
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () {
                        setState(() {
                          showLast = true;
                        });
                      },
                      child: Text(
                        "Show last",
                        textScaler: this.widget.textScaler,
                        style: style,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
