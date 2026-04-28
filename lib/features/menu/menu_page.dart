import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_categories/menu_categories_repository.dart';
import '../menu_categories/menu_category.dart';
import '../menu_items/menu_item.dart';
import '../menu_items/menu_items_provider.dart';
import '../menu_items/menu_items_repository.dart';

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({super.key});

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage>
    with SingleTickerProviderStateMixin {
  bool _fabOpen = false;

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(currentMenuProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Menù')),
      floatingActionButton: _buildExpandableFab(context),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            menuAsync.when(
              data: (menu) => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0CC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.restaurant_menu),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            menu.name,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gestisci categorie e piatti del menu corrente',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Errore menu: $e'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: categoriesAsync.when(
                data: (categories) {
                  return itemsAsync.when(
                    data: (items) {
                      if (categories.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      return ListView.separated(
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final categoryItems = items
                              .where((item) => item.categoryId == category.id)
                              .toList();

                          return _buildCategoryTile(
                            context,
                            category,
                            categoryItems,
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Errore piatti: $e')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Errore categorie: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Nessuna categoria ancora',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Inizia creando una categoria oppure un piatto.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => _openCreateCategoryDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Nuova categoria'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openCreateItemDialog(context),
                icon: const Icon(Icons.fastfood),
                label: const Text('Nuovo piatto'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    MenuCategory category,
    List<MenuItemModel> items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.52),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD9C5),
              borderRadius: BorderRadius.circular(21),
            ),
            alignment: Alignment.center,
            child: Text(
              '${items.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            category.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            items.isEmpty
                ? 'Nessun piatto'
                : '${items.length} ${items.length == 1 ? 'piatto' : 'piatti'}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Aggiungi piatto',
                onPressed: () => _openCreateItemDialog(
                  context,
                  preselectedCategory: category,
                ),
                icon: const Icon(Icons.add_circle_outline),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openEditCategoryDialog(context, category);
                  } else if (value == 'delete') {
                    _confirmDeleteCategory(context, category);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Modifica categoria'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Elimina categoria'),
                  ),
                ],
              ),
            ],
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
            ...items.map((item) => _buildItemTile(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, MenuItemModel item) {
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
                  item.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.description != null &&
                    item.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.description!,
                      style: TextStyle(color: Colors.black.withOpacity(0.65)),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip(item.formattedPrice),
                    if (item.isSoldOut) _chip('Esaurito'),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _openEditItemDialog(context, item);
              } else if (value == 'delete') {
                _confirmDeleteItem(context, item);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifica piatto')),
              PopupMenuItem(value: 'delete', child: Text('Elimina piatto')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6D8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }

  Widget _buildExpandableFab(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _fabOpen
              ? Column(
                  key: const ValueKey('openFab'),
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'addItem',
                      onPressed: () {
                        setState(() => _fabOpen = false);
                        _openCreateItemDialog(context);
                      },
                      label: const Text('Nuovo piatto'),
                      icon: const Icon(Icons.fastfood),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.extended(
                      heroTag: 'addCategory',
                      onPressed: () {
                        setState(() => _fabOpen = false);
                        _openCreateCategoryDialog(context);
                      },
                      label: const Text('Nuova categoria'),
                      icon: const Icon(Icons.folder_open),
                    ),
                    const SizedBox(height: 10),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton.extended(
          heroTag: 'mainFab',
          onPressed: () => setState(() => _fabOpen = !_fabOpen),
          icon: Icon(_fabOpen ? Icons.close : Icons.add),
          label: Text(_fabOpen ? 'Chiudi' : 'Aggiungi'),
        ),
      ],
    );
  }

  Future<void> _openCreateCategoryDialog(BuildContext context) async {
    final categories = await ref.read(menuCategoriesProvider.future);
    final menu = await ref.read(currentMenuProvider.future);

    if (!context.mounted) return;

    final nameController = TextEditingController();
    final positionController = TextEditingController(
      text: (categories.length + 1).toString(),
    );

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nuova categoria'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: positionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Posizione nel menu',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final position =
                              int.tryParse(positionController.text.trim()) ??
                              (categories.length + 1);

                          if (name.isEmpty) return;

                          setState(() => saving = true);

                          try {
                            await ref
                                .read(menuCategoriesRepositoryProvider)
                                .createCategory(
                                  menuId: menu.id,
                                  name: name,
                                  sortOrder: position,
                                );

                            ref.invalidate(menuCategoriesProvider);

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => saving = false);
                            }
                          }
                        },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openEditCategoryDialog(
    BuildContext context,
    MenuCategory category,
  ) async {
    final nameController = TextEditingController(text: category.name);
    final positionController = TextEditingController(
      text: category.sortOrder.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifica categoria'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: positionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Posizione nel menu',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final position =
                              int.tryParse(positionController.text.trim()) ?? 0;

                          if (name.isEmpty) return;

                          setState(() => saving = true);

                          try {
                            await ref
                                .read(menuCategoriesRepositoryProvider)
                                .updateCategory(
                                  id: category.id,
                                  name: name,
                                  sortOrder: position,
                                );

                            ref.invalidate(menuCategoriesProvider);

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => saving = false);
                            }
                          }
                        },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    MenuCategory category,
  ) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Elimina categoria'),
            content: Text(
              'Vuoi eliminare "${category.name}"? Assicurati che non contenga piatti collegati.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await ref
        .read(menuCategoriesRepositoryProvider)
        .deleteCategory(category.id);
    ref.invalidate(menuCategoriesProvider);
    ref.invalidate(menuItemsProvider);
  }

  Future<void> _openCreateItemDialog(
    BuildContext context, {
    MenuCategory? preselectedCategory,
  }) async {
    final menu = await ref.read(currentMenuProvider.future);
    final categories = await ref.read(menuCategoriesProvider.future);
    final items = await ref.read(menuItemsProvider.future);

    if (!context.mounted) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea prima almeno una categoria')),
      );
      return;
    }

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final positionController = TextEditingController(
      text: (items.length + 1).toString(),
    );

    String selectedCategoryId = preselectedCategory?.id ?? categories.first.id;

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nuovo piatto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedCategoryId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome piatto',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Prezzo (€)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: positionController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Posizione nella categoria',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final description = descriptionController.text.trim();
                          final priceText = priceController.text
                              .trim()
                              .replaceAll(',', '.');
                          final price = double.tryParse(priceText);
                          final position =
                              int.tryParse(positionController.text.trim()) ??
                              (items.length + 1);

                          if (name.isEmpty || price == null) return;

                          setState(() => saving = true);

                          try {
                            await ref
                                .read(menuItemsRepositoryProvider)
                                .createItem(
                                  menuId: menu.id,
                                  categoryId: selectedCategoryId,
                                  name: name,
                                  description: description.isEmpty
                                      ? null
                                      : description,
                                  priceCents: (price * 100).round(),
                                  currency: 'EUR',
                                  sortOrder: position,
                                );

                            ref.invalidate(menuItemsProvider);

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => saving = false);
                            }
                          }
                        },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openEditItemDialog(
    BuildContext context,
    MenuItemModel item,
  ) async {
    final categories = await ref.read(menuCategoriesProvider.future);

    if (!context.mounted) return;

    final nameController = TextEditingController(text: item.name);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    final priceController = TextEditingController(
      text: (item.priceCents / 100).toStringAsFixed(2),
    );
    final positionController = TextEditingController(
      text: item.sortOrder.toString(),
    );

    String selectedCategoryId = item.categoryId;
    bool soldOut = item.isSoldOut;

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifica piatto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedCategoryId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome piatto',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Prezzo (€)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: positionController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Posizione nella categoria',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: soldOut,
                      title: const Text('Esaurito'),
                      onChanged: (value) {
                        setState(() => soldOut = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final description = descriptionController.text.trim();
                          final priceText = priceController.text
                              .trim()
                              .replaceAll(',', '.');
                          final price = double.tryParse(priceText);
                          final position =
                              int.tryParse(positionController.text.trim()) ?? 0;

                          if (name.isEmpty || price == null) return;

                          setState(() => saving = true);

                          try {
                            await ref
                                .read(menuItemsRepositoryProvider)
                                .updateItem(
                                  id: item.id,
                                  categoryId: selectedCategoryId,
                                  name: name,
                                  description: description.isEmpty
                                      ? null
                                      : description,
                                  priceCents: (price * 100).round(),
                                  currency: 'EUR',
                                  sortOrder: position,
                                  isSoldOut: soldOut,
                                );

                            ref.invalidate(menuItemsProvider);

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => saving = false);
                            }
                          }
                        },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    MenuItemModel item,
  ) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Elimina piatto'),
            content: Text('Vuoi eliminare "${item.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await ref.read(menuItemsRepositoryProvider).deleteItem(item.id);
    ref.invalidate(menuItemsProvider);
  }
}
