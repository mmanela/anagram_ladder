import 'package:flutter/material.dart';

class HintPanel extends StatefulWidget {
  final List<String> words;

  HintPanel({super.key, required this.words}) : assert(words.isNotEmpty);

  @override
  State<HintPanel> createState() => _HintPanelState();
}

class _HintPanelState extends State<HintPanel> {
  int _answer = 0;
  final _firstLetters = <int>{};
  final _lastLetters = <int>{};

  Widget _endLetter({required bool first}) {
    final revealed = (first ? _firstLetters : _lastLetters).contains(_answer);
    final word = widget.words[_answer];
    final position = first ? 'first' : 'last';
    final letter = first ? word[0] : word[word.length - 1];
    final colors = Theme.of(context).colorScheme;
    void reveal() => setState(() {
      (first ? _firstLetters : _lastLetters).add(_answer);
    });

    return Semantics(
      key: ValueKey(first ? 'hint-first' : 'hint-last'),
      button: !revealed,
      liveRegion: true,
      label: revealed
          ? 'Answer ${_answer + 1}, $position letter: $letter'
          : 'Reveal $position letter for answer ${_answer + 1}',
      onTap: revealed ? null : reveal,
      child: ExcludeSemantics(
        child: Tooltip(
          message: revealed
              ? '$position letter: $letter'
              : 'Reveal $position letter',
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(56, 56),
              padding: const EdgeInsets.all(8),
              backgroundColor: revealed ? colors.primaryContainer : null,
              disabledForegroundColor: colors.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: revealed ? null : reveal,
            child: SizedBox(
              width: 32,
              height: 32,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  revealed ? letter : '?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.words[_answer];
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 8,
            overflowSpacing: 4,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  widget.words.length == 1
                      ? 'Answer hint'
                      : 'Answer ${_answer + 1} of ${widget.words.length}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (widget.words.length > 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Previous answer',
                      onPressed: _answer == 0
                          ? null
                          : () => setState(() => _answer--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Next answer',
                      onPressed: _answer == widget.words.length - 1
                          ? null
                          : () => setState(() => _answer++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _endLetter(first: true),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Semantics(
                    label: '${word.length - 2} hidden middle letters',
                    excludeSemantics: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        List.filled(word.length - 2, '_').join(' '),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ),
              _endLetter(first: false),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Tap ? to reveal'),
        ],
      ),
    );
  }
}
