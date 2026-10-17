import 'package:anagram_ladder/models/gameState.dart';
import 'package:anagram_ladder/models/gameStore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PayPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<GameStore>();
    final colors = Theme.of(context).colorScheme;
    final pending = store.storeEvent == StoreEvent.purchasePending;
    const firstPaidLevel = GameState.DefaultLevelsPerWorld + 1;
    const lastPaidLevel = GameState.UnlockedLevelsPerWorld;
    const paidLevelCount = lastPaidLevel - GameState.DefaultLevelsPerWorld;

    return Scaffold(
      appBar: AppBar(title: const Text('Store')),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Icon(Icons.stairs_rounded, size: 48, color: colors.primary),
                    const SizedBox(height: 20),
                    Text(
                      'Keep climbing',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unlock ladders $firstPaidLevel to $lastPaidLevel in every difficulty. '
                      'A one-time purchase, with no timers or subscriptions.',
                    ),
                    const SizedBox(height: 24),
                    if (!store.isLoaded) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text('Connecting to the store...'),
                    ] else ...[
                      if (store.errorMessage != null ||
                          !store.isAvailable ||
                          store.products.isEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  store.errorMessage ??
                                      (store.isAvailable
                                          ? 'Extra ladders are unavailable right now.'
                                          : 'The store is unavailable right now.'),
                                  style: TextStyle(color: colors.error),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Your free ladders are still ready to play.',
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: store.isBusy
                                      ? null
                                      : store.initialize,
                                  child: const Text('Retry connection'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      for (final product in store.products)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '$paidLevelCount more ladders in every difficulty',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 20),
                                if (store.hasUnlocked51To100)
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle_outline),
                                      SizedBox(width: 12),
                                      Expanded(child: Text('Unlocked')),
                                    ],
                                  )
                                else
                                  FilledButton(
                                    onPressed: store.isBusy
                                        ? null
                                        : () => store.purchaseProduct(product),
                                    child: Text('Unlock for ${product.price}'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: store.isBusy || !store.isAvailable
                            ? null
                            : store.restorePurchases,
                        child: Text(
                          store.isRestoring
                              ? 'Restoring purchases...'
                              : 'Restore Purchases',
                        ),
                      ),
                      if (store.isRestoring) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      if (store.statusMessage != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(store.statusMessage!),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (pending) ...[
              const ModalBarrier(dismissible: false, color: Colors.black26),
              Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        const Text('Waiting for the store...'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
