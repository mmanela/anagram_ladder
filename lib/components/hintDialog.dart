import 'dart:math';

import 'package:flutter/material.dart';

class HintDialog extends StatelessWidget {
  static Future<void> show(
    BuildContext context,
    List<String> words, {
    Key? key,
  }) => showDialog<void>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    builder: (_) => HintDialog(key: key, words: words),
  );

  static void hide(BuildContext context) => Navigator.pop(context);

  final List<String> words;
  HintDialog({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: max(0, size.height - 64),
            maxWidth: 500,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'A little nudge',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text('Reveal the first or last letter of any answer.'),
                const SizedBox(height: 20),
                for (var index = 0; index < words.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: WordHintControl(
                      possibility: index,
                      word: words[index],
                      textScaler: textScaler,
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => hide(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WordHintControl extends StatefulWidget {
  final String word;
  final int possibility;
  final TextScaler textScaler;
  WordHintControl({
    super.key,
    required this.possibility,
    required this.word,
    required this.textScaler,
  });

  @override
  State<WordHintControl> createState() => _WordHintControlState();
}

class _WordHintControlState extends State<WordHintControl> {
  bool showFirst = false;
  bool showLast = false;

  Widget _reveal(BuildContext context, {required bool first}) {
    final revealed = first ? showFirst : showLast;
    final letter = first ? widget.word[0] : widget.word[widget.word.length - 1];
    final label = first ? 'first' : 'last';
    return Semantics(
      liveRegion: revealed,
      label: revealed ? '$label letter: $letter' : null,
      child: revealed
          ? Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                letter,
                textScaler: widget.textScaler,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : OutlinedButton(
              onPressed: () => setState(() {
                if (first) {
                  showFirst = true;
                } else {
                  showLast = true;
                }
              }),
              child: Text('Show $label', textScaler: widget.textScaler),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Word ${widget.possibility + 1}',
          textScaler: widget.textScaler,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _reveal(context, first: true)),
            const SizedBox(width: 12),
            Expanded(child: _reveal(context, first: false)),
          ],
        ),
      ],
    );
  }
}
