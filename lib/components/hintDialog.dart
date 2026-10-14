import 'package:anagram_ladder/anagram/hintWordSelector.dart';
import 'package:flutter/material.dart';

class HintDialog extends StatefulWidget {
  static Future<void> show(
    BuildContext context,
    List<String> words, {
    Key? key,
  }) => showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (_) => HintDialog(key: key, words: words),
  );

  final List<String> words;

  HintDialog({super.key, required this.words});

  @override
  State<HintDialog> createState() => _HintDialogState();
}

class _HintDialogState extends State<HintDialog> {
  late Future<String> _word;
  bool _showLast = false;

  @override
  void initState() {
    super.initState();
    _word = _selectWord();
  }

  Future<String> _selectWord() async {
    try {
      return await HintWordSelector.shared.select(widget.words);
    } catch (error) {
      debugPrint('Hints: could not select an answer: $error');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _word,
      builder: (context, snapshot) {
        final word = snapshot.data;
        return AlertDialog(
          scrollable: true,
          title: const Text('Hint'),
          content: snapshot.hasError
              ? const Text('Could not load a hint. Please try again.')
              : word == null
              ? const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Finding a hint',
                  ),
                )
              : Semantics(
                  liveRegion: true,
                  label:
                      '${word.length}-letter word. First letter: ${word[0]}.'
                      '${_showLast ? ' Last letter: ${word[word.length - 1]}.' : ''}',
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      List.generate(
                        word.length,
                        (index) =>
                            index == 0 ||
                                (_showLast && index == word.length - 1)
                            ? word[index]
                            : '_',
                      ).join(' '),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
          actions: [
            if (snapshot.hasError)
              TextButton(
                onPressed: () => setState(() => _word = _selectWord()),
                child: const Text('Retry'),
              ),
            if (word != null && !_showLast)
              TextButton(
                onPressed: () => setState(() => _showLast = true),
                child: const Text('Show last letter'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
