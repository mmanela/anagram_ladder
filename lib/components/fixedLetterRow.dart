import 'package:anagram_ladder/components/letterBoxDimensions.dart';
import 'package:flutter/material.dart';

class FixedLetterRow extends StatelessWidget {
  final List<String> _letters;
  final LetterBoxDimensions _dimensions;
  FixedLetterRow(this._letters, this._dimensions);

  @override
  Widget build(BuildContext context) {
    final solved = _letters.any((letter) => letter.isNotEmpty);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: solved
          ? 'Solved word ${_letters.join()}'
          : '${_letters.length}-letter rung',
      child: ExcludeSemantics(
        child: SizedBox(
          height: _dimensions.boxHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final letter in _letters)
                Container(
                  width: _dimensions.boxWidth - 6,
                  margin: const EdgeInsets.all(3),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: solved
                        ? const Color(0xFFE8F3EC)
                        : colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: solved
                          ? const Color(0xFFBDD8C7)
                          : colors.outlineVariant,
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        letter,
                        textScaler: _dimensions.textScaler,
                        style: TextStyle(
                          fontSize: _dimensions.boxFontSize,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF256144),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
