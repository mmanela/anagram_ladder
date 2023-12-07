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
    final textScaleFactor = min(1.25, MediaQuery.of(context).textScaleFactor);
    final double heightBuffer = 100;
    final double heightPerRow = 55 * textScaleFactor;
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
                    padding: EdgeInsets.all(12.0),
                    child: _hintDialogContents(context, textScaleFactor)))));
  }

  Widget _hintDialogContents(BuildContext context, double textScaleFactor) {
    final hints = words
        .indices()
        .map((i) => Flexible(
            child: WordHintControl(
                possibility: i,
                word: words[i],
                textScaleFactor: textScaleFactor)))
        .toList();
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: Text(
                  "Reveal the first and/or last letter of each of the possible words",
                  textScaleFactor: textScaleFactor)),
          const SizedBox(
            height: 10,
          ),
          ...hints,
          const SizedBox(
            height: 20,
          ),
          ElevatedButton(
              onPressed: () {
                HintDialog.hide(context);
              },
              child: Text(
                "Close",
                textScaleFactor: textScaleFactor,
                style: TextStyle(fontSize: 20),
              ))
        ]);
  }
}

class WordHintControl extends StatefulWidget {
  final String word;
  final int possibility;
  final double textScaleFactor;
  WordHintControl(
      {Key? key,
      required this.possibility,
      required this.word,
      required this.textScaleFactor});

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
    const letterStyle =
        TextStyle(fontSize: letterSize, fontWeight: FontWeight.bold);
    return Row(children: [
      Text("Word ${widget.possibility + 1}",
          textScaleFactor: this.widget.textScaleFactor,
          style: const TextStyle(
              fontSize: labelSize, fontWeight: FontWeight.bold)),
      SizedBox(width: 10),
      Flexible(
          child: Center(
              child: showFirst
                  ? Container(
                      padding: const EdgeInsets.all(0.0),
                      height: rowHeight,
                      child: Center(
                          child: Text(this.widget.word[0],
                              textScaleFactor: this.widget.textScaleFactor,
                              style: letterStyle)))
                  : Container(
                      padding: const EdgeInsets.all(0.0),
                      height: rowHeight,
                      child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () {
                            setState(() {
                              showFirst = true;
                            });
                          },
                          child: Text("Show first",
                              textScaleFactor: this.widget.textScaleFactor,
                              style: style))))),
      Flexible(
          child: Center(
              child: showLast
                  ? Container(
                      padding: const EdgeInsets.all(0.0),
                      height: rowHeight,
                      child: Center(
                          child: Text(
                              this.widget.word[this.widget.word.length - 1],
                              textScaleFactor: this.widget.textScaleFactor,
                              style: letterStyle)))
                  : Container(
                      padding: const EdgeInsets.all(0.0),
                      height: rowHeight,
                      child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () {
                            setState(() {
                              showLast = true;
                            });
                          },
                          child: Text("Show last",
                              textScaleFactor: this.widget.textScaleFactor,
                              style: style)))))
    ]);
  }
}
