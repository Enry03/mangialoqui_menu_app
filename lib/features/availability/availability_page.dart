import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../menu_categories/menu_categories_provider.dart';
import '../menu_categories/menu_category.dart';
import '../menu_items/menu_item.dart';
import '../menu_items/menu_items_provider.dart';
import '../menu_items/menu_items_repository.dart';

class AvailabilityPage extends ConsumerWidget {
  const AvailabilityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Disponibilità')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: categoriesAsync.when(
          data: (categories) {
            return itemsAsync.when(
              data: (items) {
                if (categories.isEmpty || items.isEmpty) {
                  return const _EmptyAvailabilityView();
                }

                return ListView.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final categoryItems = items
                        .where((item) => item.categoryId == category.id)
                        .toList();

                    return _AvailabilityCategoryCard(
                      category: category,
                      items: categoryItems,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Errore piatti: $e')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Errore categorie: $e')),
        ),
      ),
    );
  }
}

class _EmptyAvailabilityView extends StatelessWidget {
  const _EmptyAvailabilityView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Nessun piatto ancora',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aggiungi piatti dalla pagina Menù per gestire qui il sold out.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCategoryCard extends ConsumerWidget {
  final MenuCategory category;
  final List<MenuItemModel> items;

  const _AvailabilityCategoryCard({
    required this.category,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          title: Text(
            category.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            items.isEmpty
                ? 'Nessun piatto'
                : '${items.length} ${items.length == 1 ? 'piatto' : 'piatti'}',
          ),
          children: [
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Questa categoria non ha ancora piatti.'),
              ),
            ...items.map((item) => _AvailabilityItemRow(item: item)),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityItemRow extends ConsumerStatefulWidget {
  final MenuItemModel item;

  const _AvailabilityItemRow({required this.item});

  @override
  ConsumerState<_AvailabilityItemRow> createState() =>
      _AvailabilityItemRowState();
}

class _AvailabilityItemRowState extends ConsumerState<_AvailabilityItemRow> {
  late bool isSoldOut;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    isSoldOut = widget.item.isSoldOut;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.item.description != null &&
                    widget.item.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.item.description!,
                      style: TextStyle(color: Colors.black.withOpacity(0.65)),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  widget.item.formattedPrice,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSoldOut
                        ? const Color(0xFFFFD9D9)
                        : const Color(0xFFDFF4E3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isSoldOut ? 'Sold out' : 'Disponibile',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Switch(
                value: isSoldOut,
                onChanged: isSaving
                    ? null
                    : (value) async {
                        setState(() {
                          isSoldOut = value;
                          isSaving = true;
                        });

                        try {
                          await ref
                              .read(menuItemsRepositoryProvider)
                              .setSoldOut(id: widget.item.id, isSoldOut: value);

                          ref.invalidate(menuItemsProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  value
                                      ? '${widget.item.name} segnato come sold out'
                                      : '${widget.item.name} di nuovo disponibile',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          // rollback visivo
                          setState(() {
                            isSoldOut = !value;
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Errore: $e')),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => isSaving = false);
                          }
                        }
                      },
              ),
              Text(
                isSoldOut ? 'ON' : 'OFF',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSoldOut ? Colors.redAccent : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
