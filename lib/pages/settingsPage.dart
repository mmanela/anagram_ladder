import 'package:anagram_ladder/models/gameState.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _versionText = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(
              () => _versionText =
                  '${info.appName} v${info.version}+${info.buildNumber}',
            );
          }
        })
        .catchError((Object error) {
          debugPrint('Settings: could not load version: $error');
          if (mounted)
            setState(() => _versionText = 'Version information unavailable');
        });
  }

  void _showError(Object error) {
    debugPrint('Settings: $error');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That could not be completed. Please try again.'),
        ),
      );
    }
  }

  Future<void> _resetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Reset all ladder progress?'),
        content: const Text(
          'This removes all solved words, saved ladder progress, '
          'and daily results. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset progress'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<GameState>().reset();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Game progress reset')));
      }
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.all(16),
                    title: const Text('Haptic feedback'),
                    subtitle: const Text(
                      'A subtle tick for letter moves and solved words.',
                    ),
                    value: game.hapticsEnabled,
                    onChanged: (value) async {
                      try {
                        await game.setHapticsEnabled(value);
                      } catch (error) {
                        _showError(error);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('Send feedback'),
                    subtitle: const Text(
                      'Ideas, tricky words, or something not working?',
                    ),
                    onTap: () async {
                      try {
                        final opened = await launchUrl(
                          Uri(
                            scheme: 'mailto',
                            path: 'AnagramLadder@gmail.com',
                            query: 'subject=Feedback',
                          ),
                        );
                        if (!opened)
                          _showError('No email application is available');
                      } catch (error) {
                        _showError(error);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _resetProgress,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset progress'),
                ),
                const SizedBox(height: 24),
                Text(
                  _versionText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
