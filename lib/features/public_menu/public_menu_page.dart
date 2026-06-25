import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'public_menu_provider.dart';

class PublicMenuPage extends ConsumerWidget {
  final String restaurantSlug;

  const PublicMenuPage({super.key, required this.restaurantSlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicMenuAsync = ref.watch(publicMenuProvider(restaurantSlug));

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: publicMenuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Errore caricamento menu: $e'),
          ),
        ),
        data: (data) {
          final groupedItems = {
            for (final category in data.categories)
              category.id: data.items
                  .where((item) => item.categoryId == category.id)
                  .toList(),
          };

          final hasContent =
              data.categories.isNotEmpty || data.items.isNotEmpty;

          if (!hasContent) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nessun menù pubblicato per questo ristorante.'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                data.menu.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              for (final category in data.categories) ...[
                Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...groupedItems[category.id]!.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              if (item.description != null &&
                                  item.description!.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    item.description!,
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              if (item.isSoldOut)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Esaurito',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          item.formattedPrice,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          );
        },
      ),
    );
  }
}
