import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_categories/menu_category.dart';
import '../menu_items/menu_item.dart';
import '../menu_items/menu_items_provider.dart';

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({super.key});

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage>
    with SingleTickerProviderStateMixin {
  bool _fabOpen = false;
  bool _movingCategory = false;

  final Map<String, List<String>> _optimisticItemOrderByCategory =
      <String, List<String>>{};

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(currentMenuProvider);
    final categoriesAsync = ref.watch(allMenuCategoriesProvider);
    final itemsAsync = ref.watch(allMenuItemsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Menù')),
      floatingActionButton: _buildExpandableFab(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTint, AppColors.background],
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
                          color: AppColors.primary.withValues(alpha: 0.05),
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
                              color: AppColors.primary.withValues(alpha: 0.10),
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

                        final activeCategories = categories
                            .where((category) => category.menuCategoryActive)
                            .toList();

                        final inactiveCategories = categories
                            .where((category) => !category.menuCategoryActive)
                            .toList();

                        return ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            if (activeCategories.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  inactiveCategories.isEmpty
                                      ? 'Nessuna categoria ancora.'
                                      : 'Nessuna categoria attiva.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ...List<Widget>.generate(
                              activeCategories.length,
                              (index) {
                                final category = activeCategories[index];
                                final categoryItems = items
                                    .where(
                                      (item) =>
                                          item.categoryId == category.id,
                                    )
                                    .toList();

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildCategoryTile(
                                    context,
                                    category,
                                    categoryItems,
                                    allCategories: categories,
                                    orderedCategories: activeCategories,
                                    categoryIndex: index,
                                  ),
                                );
                              },
                            ),
                            if (inactiveCategories.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Categorie disattivate',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              ...List<Widget>.generate(
                                inactiveCategories.length,
                                (index) {
                                  final category = inactiveCategories[index];
                                  final categoryItems = items
                                      .where(
                                        (item) =>
                                            item.categoryId == category.id,
                                      )
                                      .toList();

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child: _buildCategoryTile(
                                      context,
                                      category,
                                      categoryItems,
                                      allCategories: categories,
                                      orderedCategories:
                                          inactiveCategories,
                                      categoryIndex: index,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
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
              color: AppColors.primary.withValues(alpha: 0.05),
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
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
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
    List<MenuItemModel> items, {
    required List<MenuCategory> allCategories,
    required List<MenuCategory> orderedCategories,
    required int categoryIndex,
  }) {
    final theme = Theme.of(context);
    final orderedItems = List<MenuItemModel>.from(items);
    final optimisticOrder =
        _optimisticItemOrderByCategory[category.id];

    if (optimisticOrder != null) {
      final orderById = <String, int>{
        for (var index = 0; index < optimisticOrder.length; index++)
          optimisticOrder[index]: index,
      };

      orderedItems.sort((left, right) {
        final leftIndex = orderById[left.id];
        final rightIndex = orderById[right.id];

        if (leftIndex != null && rightIndex != null) {
          return leftIndex.compareTo(rightIndex);
        }

        if (leftIndex != null) {
          return -1;
        }

        if (rightIndex != null) {
          return 1;
        }

        return left.sortOrder.compareTo(right.sortOrder);
      });
    }

    final activeItems = orderedItems
        .where((item) => item.menuItemActive)
        .toList();
    final inactiveItems = orderedItems
        .where((item) => !item.menuItemActive)
        .toList();
    final categoryActive = category.menuCategoryActive;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
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
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${activeItems.length}',
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
              color: categoryActive
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              letterSpacing: -0.3,
            ),
          ),
          subtitle: Text(
            !categoryActive
                ? 'Categoria disattivata'
                : activeItems.isEmpty
                ? (inactiveItems.isEmpty
                      ? 'Nessun piatto'
                      : 'Nessun piatto attivo')
                : '${activeItems.length} ${activeItems.length == 1 ? 'piatto attivo' : 'piatti attivi'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Sposta categoria su',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    color: AppColors.primary,
                    disabledColor: AppColors.textSecondary,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 28,
                    ),
                    onPressed:
                        !_movingCategory && categoryIndex > 0
                        ? () {
                            _moveCategory(
                              allCategories: allCategories,
                              visibleCategories: orderedCategories,
                              currentIndex: categoryIndex,
                              direction: -1,
                            );
                          }
                        : null,
                    icon: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sposta categoria giù',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    color: AppColors.primary,
                    disabledColor: AppColors.textSecondary,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 28,
                    ),
                    onPressed:
                        !_movingCategory &&
                            categoryIndex <
                                orderedCategories.length - 1
                        ? () {
                            _moveCategory(
                              allCategories: allCategories,
                              visibleCategories: orderedCategories,
                              currentIndex: categoryIndex,
                              direction: 1,
                            );
                          }
                        : null,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Aggiungi piatto',
                onPressed: categoryActive
                    ? () => _openCreateItemDialog(
                        context,
                        preselectedCategory: category,
                      )
                    : null,
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
                  } else if (value == 'deactivate') {
                    _confirmDeactivateCategory(context, category);
                  } else if (value == 'reactivate') {
                    _reactivateCategory(category);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Modifica categoria'),
                  ),
                  if (category.menuCategoryActive)
                    const PopupMenuItem(
                      value: 'deactivate',
                      child: Text('Disattiva categoria'),
                    )
                  else
                    const PopupMenuItem(
                      value: 'reactivate',
                      child: Text('Riattiva categoria'),
                    ),
                ],
              ),
            ],
          ),
          children: [
            if (activeItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  inactiveItems.isEmpty
                      ? 'Questa categoria non ha ancora piatti.'
                      : 'Questa categoria non ha piatti attivi.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (activeItems.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) => child,
                itemCount: activeItems.length,
                onReorder: (oldIndex, newIndex) {
                  _reorderCategoryItems(
                    categoryId: category.id,
                    activeItems: activeItems,
                    inactiveItems: inactiveItems,
                    reorderingActiveItems: true,
                    oldIndex: oldIndex,
                    newIndex: newIndex,
                  );
                },
                itemBuilder: (context, index) {
                  final item = activeItems[index];

                  return KeyedSubtree(
                    key: ValueKey('active-${item.id}'),
                    child: _buildItemTile(
                      context,
                      item,
                      reorderIndex: index,
                    ),
                  );
                },
              ),
            if (inactiveItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Piatti disattivati',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) => child,
                itemCount: inactiveItems.length,
                onReorder: (oldIndex, newIndex) {
                  _reorderCategoryItems(
                    categoryId: category.id,
                    activeItems: activeItems,
                    inactiveItems: inactiveItems,
                    reorderingActiveItems: false,
                    oldIndex: oldIndex,
                    newIndex: newIndex,
                  );
                },
                itemBuilder: (context, index) {
                  final item = inactiveItems[index];

                  return KeyedSubtree(
                    key: ValueKey('inactive-${item.id}'),
                    child: _buildItemTile(
                      context,
                      item,
                      reorderIndex: index,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(
    BuildContext context,
    MenuItemModel item, {
    required int reorderIndex,
  }) {
    final theme = Theme.of(context);
    final itemActive = item.menuItemActive;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
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
                    color: itemActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
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
                    ...item.allergens.map(
                      (allergen) => _chip(MenuAllergen.label(allergen)),
                    ),
                    if (item.isSoldOut) _chip('Esaurito', highlighted: true),
                    if (!itemActive) _chip('Disattivato'),
                  ],
                ),
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: reorderIndex,
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
              child: Icon(
                Icons.drag_handle_rounded,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          PopupMenuButton<String>(
            iconColor: AppColors.textPrimary,
            onSelected: (value) {
              if (value == 'edit') {
                _openEditItemDialog(context, item);
              } else if (value == 'deactivate') {
                _confirmDeactivateItem(context, item);
              } else if (value == 'reactivate') {
                _reactivateItem(item);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Modifica piatto'),
              ),
              if (item.menuItemActive)
                const PopupMenuItem(
                  value: 'deactivate',
                  child: Text('Disattiva piatto'),
                )
              else
                const PopupMenuItem(
                  value: 'reactivate',
                  child: Text('Riattiva piatto'),
                ),
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
        color: highlighted ? AppColors.accent : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? AppColors.accent
              : AppColors.primary.withValues(alpha: 0.10),
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

  Widget _buildAllergensSelector({
    required BuildContext context,
    required Set<String> selectedAllergens,
    required ValueChanged<Set<String>> onChanged,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Allergeni',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Seleziona gli allergeni presenti nel piatto.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MenuAllergen.values.map((allergen) {
            final selected = selectedAllergens.contains(allergen);

            return FilterChip(
              label: Text(MenuAllergen.label(allergen)),
              selected: selected,
              onSelected: (isSelected) {
                final updatedAllergens = <String>{...selectedAllergens};

                if (isSelected) {
                  updatedAllergens.add(allergen);
                } else {
                  updatedAllergens.remove(allergen);
                }

                onChanged(updatedAllergens);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  int _nextCategorySortOrder(
    List<MenuCategory> categories,
  ) {
    var maximumSortOrder = 0;

    for (final category in categories) {
      if (category.sortOrder > maximumSortOrder) {
        maximumSortOrder = category.sortOrder;
      }
    }

    return maximumSortOrder + 10;
  }

  Future<void> _moveCategory({
    required List<MenuCategory> allCategories,
    required List<MenuCategory> visibleCategories,
    required int currentIndex,
    required int direction,
  }) async {
    if (_movingCategory) {
      return;
    }

    final newIndex = currentIndex + direction;

    if (newIndex < 0 || newIndex >= visibleCategories.length) {
      return;
    }

    final reorderedVisibleCategories =
        List<MenuCategory>.from(visibleCategories);
    final movedCategory =
        reorderedVisibleCategories.removeAt(currentIndex);

    reorderedVisibleCategories.insert(newIndex, movedCategory);

    final visibleCategoryIds = visibleCategories
        .map((category) => category.id)
        .toSet();

    var visibleIndex = 0;

    final reorderedAllCategories = allCategories.map((category) {
      if (!visibleCategoryIds.contains(category.id)) {
        return category;
      }

      final reorderedCategory =
          reorderedVisibleCategories[visibleIndex];
      visibleIndex += 1;
      return reorderedCategory;
    }).toList();

    setState(() => _movingCategory = true);

    try {
      for (
        var index = 0;
        index < reorderedAllCategories.length;
        index++
      ) {
        final category = reorderedAllCategories[index];

        await ref
            .read(menuCategoriesRepositoryProvider)
            .updateCategory(
              id: category.id,
              name: category.name,
              sortOrder: (index + 1) * 10,
            );
      }

      ref.invalidate(menuCategoriesProvider);
      ref.invalidate(allMenuCategoriesProvider);

      await ref.read(allMenuCategoriesProvider.future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossibile salvare il nuovo ordine delle categorie.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _movingCategory = false);
      }
    }
  }

  int _nextItemSortOrder({
    required List<MenuItemModel> items,
    required String categoryId,
    String? excludedItemId,
  }) {
    var maximumSortOrder = 0;

    for (final item in items) {
      if (item.categoryId != categoryId ||
          item.id == excludedItemId) {
        continue;
      }

      if (item.sortOrder > maximumSortOrder) {
        maximumSortOrder = item.sortOrder;
      }
    }

    return maximumSortOrder + 10;
  }

  Future<void> _reorderCategoryItems({
    required String categoryId,
    required List<MenuItemModel> activeItems,
    required List<MenuItemModel> inactiveItems,
    required bool reorderingActiveItems,
    required int oldIndex,
    required int newIndex,
  }) async {
    final reorderedActiveItems =
        List<MenuItemModel>.from(activeItems);
    final reorderedInactiveItems =
        List<MenuItemModel>.from(inactiveItems);

    final targetItems = reorderingActiveItems
        ? reorderedActiveItems
        : reorderedInactiveItems;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    if (oldIndex == newIndex) {
      return;
    }

    final movedItem = targetItems.removeAt(oldIndex);
    targetItems.insert(newIndex, movedItem);

    final reorderedItems = <MenuItemModel>[
      ...reorderedActiveItems,
      ...reorderedInactiveItems,
    ];

    setState(() {
      _optimisticItemOrderByCategory[categoryId] =
          reorderedItems.map((item) => item.id).toList();
    });

    try {
      await ref
          .read(menuItemsRepositoryProvider)
          .updateItemsOrder(reorderedItems);

      if (!mounted) {
        return;
      }

      ref.invalidate(menuItemsProvider);
      ref.invalidate(allMenuItemsProvider);

      await ref.read(allMenuItemsProvider.future);

      if (!mounted) {
        return;
      }

      setState(() {
        _optimisticItemOrderByCategory.remove(categoryId);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _optimisticItemOrderByCategory.remove(categoryId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile salvare il nuovo ordine dei piatti.',
          ),
        ),
      );
    }
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
    final categories = await ref.read(allMenuCategoriesProvider.future);
    final menu = await ref.read(currentMenuProvider.future);

    if (!context.mounted) return;

    final nameController = TextEditingController();

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

                          if (name.isEmpty) return;

                          final sortOrder =
                              _nextCategorySortOrder(categories);

                          setState(() => saving = true);

                          try {
                            await ref
                                .read(menuCategoriesRepositoryProvider)
                                .createCategory(
                                  menuId: menu.id,
                                  name: name,
                                  sortOrder: sortOrder,
                                );

                            ref.invalidate(menuCategoriesProvider);
                            ref.invalidate(allMenuCategoriesProvider);
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

                          if (name.isEmpty) return;

                          setState(() => saving = true);

                          try {
                            await ref
                                .read(menuCategoriesRepositoryProvider)
                                .updateCategory(
                                  id: category.id,
                                  name: name,
                                  sortOrder: category.sortOrder,
                                );

                            ref.invalidate(menuCategoriesProvider);
                            ref.invalidate(allMenuCategoriesProvider);
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

  Future<void> _confirmDeactivateCategory(
    BuildContext context,
    MenuCategory category,
  ) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Disattiva categoria'),
            content: Text(
              'Vuoi disattivare "${category.name}"? La categoria non sarà più visibile, ma potrai riattivarla quando vuoi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Disattiva'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await ref
        .read(menuCategoriesRepositoryProvider)
        .deactivateCategory(category.id);

    ref.invalidate(menuCategoriesProvider);
    ref.invalidate(allMenuCategoriesProvider);
    ref.invalidate(menuItemsProvider);
    ref.invalidate(allMenuItemsProvider);
  }

  Future<void> _reactivateCategory(MenuCategory category) async {
    await ref
        .read(menuCategoriesRepositoryProvider)
        .reactivateCategory(category.id);

    ref.invalidate(menuCategoriesProvider);
    ref.invalidate(allMenuCategoriesProvider);
    ref.invalidate(menuItemsProvider);
    ref.invalidate(allMenuItemsProvider);
  }

  Future<void> _openCreateItemDialog(
    BuildContext context, {
    MenuCategory? preselectedCategory,
  }) async {
    final menu = await ref.read(currentMenuProvider.future);
    final categories = await ref.read(menuCategoriesProvider.future);
    final items = await ref.read(allMenuItemsProvider.future);

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

    String selectedCategoryId = preselectedCategory?.id ?? categories.first.id;
    Set<String> selectedAllergens = <String>{};

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
                    _buildAllergensSelector(
                      context: context,
                      selectedAllergens: selectedAllergens,
                      onChanged: (value) {
                        setState(() => selectedAllergens = value);
                      },
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

                          if (name.isEmpty || price == null) return;

                          final sortOrder = _nextItemSortOrder(
                            items: items,
                            categoryId: selectedCategoryId,
                          );

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
                                  allergens: selectedAllergens.toList(),
                                  priceCents: (price * 100).round(),
                                  currency: 'EUR',
                                  sortOrder: sortOrder,
                                );

                            ref.invalidate(menuItemsProvider);
                            ref.invalidate(allMenuItemsProvider);

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
    final items = await ref.read(allMenuItemsProvider.future);

    if (!context.mounted) return;

    final nameController = TextEditingController(text: item.name);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    final priceController = TextEditingController(
      text: (item.priceCents / 100).toStringAsFixed(2),
    );

    String selectedCategoryId = item.categoryId;
    Set<String> selectedAllergens = item.allergens.toSet();

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
                    _buildAllergensSelector(
                      context: context,
                      selectedAllergens: selectedAllergens,
                      onChanged: (value) {
                        setState(() => selectedAllergens = value);
                      },
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

                          if (name.isEmpty || price == null) return;

                          final sortOrder =
                              selectedCategoryId == item.categoryId
                              ? item.sortOrder
                              : _nextItemSortOrder(
                                  items: items,
                                  categoryId: selectedCategoryId,
                                  excludedItemId: item.id,
                                );

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
                                  allergens: selectedAllergens.toList(),
                                  priceCents: (price * 100).round(),
                                  currency: 'EUR',
                                  sortOrder: sortOrder,
                                  isSoldOut: item.isSoldOut,
                                );

                            ref.invalidate(menuItemsProvider);
                            ref.invalidate(allMenuItemsProvider);

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

  Future<void> _confirmDeactivateItem(
    BuildContext context,
    MenuItemModel item,
  ) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Disattiva piatto'),
            content: Text(
              'Vuoi disattivare "${item.name}"? Il piatto non sarà più visibile, ma potrai riattivarlo quando vuoi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Disattiva'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await ref.read(menuItemsRepositoryProvider).deactivateItem(item.id);
    ref.invalidate(menuItemsProvider);
    ref.invalidate(allMenuItemsProvider);
  }

  Future<void> _reactivateItem(MenuItemModel item) async {
    await ref.read(menuItemsRepositoryProvider).reactivateItem(item.id);
    ref.invalidate(menuItemsProvider);
    ref.invalidate(allMenuItemsProvider);
  }
}
