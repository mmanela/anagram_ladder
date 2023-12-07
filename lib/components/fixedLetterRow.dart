import 'package:anagram_ladder/components/letterBoxDimensions.dart';
import 'package:flutter/material.dart';

class FixedLetterRow extends StatelessWidget {
  final List<String> _letters;
  final LetterBoxDimensions _dimensions;
  FixedLetterRow(this._letters, this._dimensions);

  @override
  Widget build(BuildContext context) {
    //print("Rendering fixed letter boxes");
    List<Widget> boxes = List.empty(growable: true);
    for (int index = 0; index < _letters.length; index++) {
      final box = Container(
          key: Key("$index"),
          width: _dimensions.boxWidth,
          child: Container(
              child: Card(
                  margin: EdgeInsets.all(4),
                  elevation: 2,
                  child: Container(
                      color: Theme.of(context).focusColor,
                      child: Center(
                          child: Text(
                        _letters[index],
                        textScaleFactor: _dimensions.textScaleFactor,
                        style: TextStyle(
                            fontSize: _dimensions.boxFontSize,
                            color: Colors.white),
                      ))))));

      boxes.add(box);
    }

    return Container(
        height: _dimensions.boxHeight,
        child: ListView(scrollDirection: Axis.horizontal, children: boxes));
  }
}
