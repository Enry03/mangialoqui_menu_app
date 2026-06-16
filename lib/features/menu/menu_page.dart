import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Menù')),
      floatingActionButton: _buildExpandableFab(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FBFF), AppColors.background],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              menuAsync.when(
                data: (menu) => TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.05),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.10),
                            ),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                menu.name,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: 24,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Gestisci categorie e piatti del menu corrente',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                          physics: const BouncingScrollPhysics(),
                          itemCount: categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Errore categorie: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.10)),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nessuna categoria ancora',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inizia creando una categoria oppure un piatto.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => _openCreateCategoryDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuova categoria'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openCreateItemDialog(context),
                  icon: const Icon(Icons.fastfood_rounded),
                  label: const Text('Nuovo piatto'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    MenuCategory category,
    List<MenuItemModel> items,
  ) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: AppColors.primary.withOpacity(0.10)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${items.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            category.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          subtitle: Text(
            items.isEmpty
                ? 'Nessun piatto'
                : '${items.length} ${items.length == 1 ? 'piatto' : 'piatti'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
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
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                ),
              ),
              PopupMenuButton<String>(
                iconColor: AppColors.textPrimary,
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
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Questa categoria non ha ancora piatti.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ...items.map((item) => _buildItemTile(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, MenuItemModel item) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.65)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (item.description != null &&
                    item.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(item.formattedPrice),
                    if (item.isSoldOut) _chip('Esaurito', highlighted: true),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            iconColor: AppColors.textPrimary,
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

  Widget _chip(String label, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primary : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? AppColors.primary
              : AppColors.primary.withOpacity(0.10),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? AppColors.white : AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
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
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                      onPressed: () {
                        setState(() => _fabOpen = false);
                        _openCreateItemDialog(context);
                      },
                      label: const Text('Nuovo piatto'),
                      icon: const Icon(Icons.fastfood_rounded),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.extended(
                      heroTag: 'addCategory',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                      onPressed: () {
                        setState(() => _fabOpen = false);
                        _openCreateCategoryDialog(context);
                      },
                      label: const Text('Nuova categoria'),
                      icon: const Icon(Icons.folder_open_rounded),
                    ),
                    const SizedBox(height: 10),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton.extended(
          heroTag: 'mainFab',
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
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
