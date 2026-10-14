import 'package:anagram_ladder/models/dailyChallenge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class DailyResultCard extends StatefulWidget {
  final DailyChallenge challenge;
  final List<int> wordLengths;
  final VoidCallback onReplay;
  final VoidCallback onBack;

  const DailyResultCard({
    super.key,
    required this.challenge,
    required this.wordLengths,
    required this.onReplay,
    required this.onBack,
  });

  @override
  State<DailyResultCard> createState() => _DailyResultCardState();
}

class _DailyResultCardState extends State<DailyResultCard> {
  bool _sharing = false;
  String get _result => widget.challenge.shareText(widget.wordLengths);

  void _showError(String message, Object error) {
    debugPrint('Daily result: $error');
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    setState(() => _sharing = true);
    final box = buttonContext.findRenderObject() as RenderBox;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _result,
          subject: 'Anagram Ladder | Daily ${widget.challenge.dateKey}',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      _showError('Could not share. You can copy the result instead.', error);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _result));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Result copied')));
      }
    } catch (error) {
      _showError('Could not copy the result. Please try again.', error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF256144),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Daily ladder complete!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(widget.challenge.dateKey, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                '${widget.wordLengths.length} rungs solved. Nicely done.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Share your result without revealing any words.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Builder(
                builder: (buttonContext) => FilledButton.icon(
                  onPressed: _sharing ? null : () => _share(buttonContext),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share result'),
                ),
              ),
              TextButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy result'),
              ),
              OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Back to daily'),
              ),
              TextButton(
                onPressed: widget.onReplay,
                child: const Text('Replay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
