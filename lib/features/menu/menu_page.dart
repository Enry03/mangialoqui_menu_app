import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_toast.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_categories/menu_category.dart';
import '../menu_items/menu_item.dart';
import '../menu_items/menu_items_provider.dart';

class _CategoryIconOption {
  final String key;
  final IconData icon;

  const _CategoryIconOption({required this.key, required this.icon});
}

const List<_CategoryIconOption> _categoryIconOptions = [
  _CategoryIconOption(
    key: 'restaurant_menu',
    icon: Icons.restaurant_menu_rounded,
  ),
  _CategoryIconOption(key: 'appetizers', icon: Icons.tapas_rounded),
  _CategoryIconOption(key: 'first_courses', icon: Icons.dinner_dining_rounded),
  _CategoryIconOption(key: 'soups', icon: LucideIcons.soup),
  _CategoryIconOption(key: 'main_courses', icon: LucideIcons.beef),
  _CategoryIconOption(key: 'fish', icon: Icons.set_meal_rounded),
  _CategoryIconOption(key: 'pizza', icon: LucideIcons.pizza),
  _CategoryIconOption(key: 'burgers', icon: Icons.lunch_dining_rounded),
  _CategoryIconOption(key: 'vegetables', icon: LucideIcons.salad),
  _CategoryIconOption(key: 'vegetarian', icon: Icons.eco_rounded),
  _CategoryIconOption(key: 'fried_food', icon: MdiIcons.frenchFries),
  _CategoryIconOption(key: 'desserts', icon: LucideIcons.cakeSlice),
  _CategoryIconOption(key: 'coffee', icon: LucideIcons.coffee),
  _CategoryIconOption(key: 'drinks', icon: LucideIcons.cupSoda),
  _CategoryIconOption(key: 'cocktails', icon: Icons.local_bar_rounded),
  _CategoryIconOption(key: 'wine', icon: LucideIcons.wine),
  _CategoryIconOption(key: 'beer', icon: Icons.sports_bar_rounded),
  _CategoryIconOption(key: 'liquor', icon: Icons.liquor_rounded),
];

IconData _categoryIconFromKey(String iconKey) {
  for (final option in _categoryIconOptions) {
    if (option.key == iconKey) {
      return option.icon;
    }
  }

  return Icons.restaurant_menu_rounded;
}

class _FastReorderableDelayedDragStartListener
    extends ReorderableDelayedDragStartListener {
  const _FastReorderableDelayedDragStartListener({
    super.key,
    required super.child,
    required super.index,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: const Duration(milliseconds: 150),
      debugOwner: this,
    );
  }
}

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({super.key});

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage>
    with SingleTickerProviderStateMixin {
  bool _fabOpen = false;
  bool _movingCategory = false;
  List<String>? _optimisticCategoryOrder;

  final Map<String, List<String>> _optimisticItemOrderByCategory =
      <String, List<String>>{};

  final Map<String, bool> _disabledItemsExpandedByCategory = <String, bool>{};

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

                        final optimisticCategoryOrder =
                            _optimisticCategoryOrder;

                        if (optimisticCategoryOrder != null) {
                          final orderById = <String, int>{
                            for (
                              var index = 0;
                              index < optimisticCategoryOrder.length;
                              index++
                            )
                              optimisticCategoryOrder[index]: index,
                          };

                          activeCategories.sort((left, right) {
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
                            if (activeCategories.isNotEmpty)
                              ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                buildDefaultDragHandles: false,
                                proxyDecorator: (child, index, animation) =>
                                    child,
                                itemCount: activeCategories.length,
                                onReorder: (oldIndex, newIndex) {
                                  _reorderCategories(
                                    allCategories: categories,
                                    activeCategories: activeCategories,
                                    oldIndex: oldIndex,
                                    newIndex: newIndex,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  final category = activeCategories[index];
                                  final categoryItems = items
                                      .where(
                                        (item) =>
                                            item.categoryId == category.id,
                                      )
                                      .toList();

                                  return _FastReorderableDelayedDragStartListener(
                                    key: ValueKey(
                                      'active-category-${category.id}',
                                    ),
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _buildCategoryTile(
                                        context,
                                        category,
                                        categoryItems,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            if (inactiveCategories.isNotEmpty)
                              _buildDisabledElementsSection(inactiveCategories),
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

  Widget _buildDisabledElementsSection(List<MenuCategory> inactiveCategories) {
    final theme = Theme.of(context);
    final categoryCount = inactiveCategories.length;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
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
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ),
          title: Text(
            'Elementi disattivati',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          subtitle: Text(
            categoryCount == 1
                ? '1 categoria disattivata'
                : '$categoryCount categorie disattivate',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Categorie disattivate',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final category in inactiveCategories)
              _buildDisabledCategoryTile(category),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledCategoryTile(MenuCategory category) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: 0.58,
            child: Container(
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
              child: Icon(
                _categoryIconFromKey(category.iconKey),
                color: AppColors.textSecondary,
                size: 23,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Opacity(
              opacity: 0.58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Categoria disattivata',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            tooltip: 'Azioni categoria',
            iconColor: AppColors.textSecondary,
            onSelected: (value) {
              if (value == 'reactivate') {
                _reactivateCategory(category);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'reactivate',
                child: Text('Riattiva categoria'),
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
    final theme = Theme.of(context);
    final orderedItems = List<MenuItemModel>.from(items);
    final optimisticOrder = _optimisticItemOrderByCategory[category.id];

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
    final disabledItemsExpanded =
        _disabledItemsExpandedByCategory[category.id] ?? false;

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
            child: Icon(
              _categoryIconFromKey(category.iconKey),
              color: AppColors.primary,
              size: 23,
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
                tooltip: 'Azioni categoria',
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
                itemBuilder: (_) => <PopupMenuEntry<String>>[
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

                  return _FastReorderableDelayedDragStartListener(
                    key: ValueKey('active-${item.id}'),
                    index: index,
                    child: _buildItemTile(context, item),
                  );
                },
              ),
            if (inactiveItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _disabledItemsExpandedByCategory[category.id] = expanded;
                    });
                  },
                  title: Row(
                    children: [
                      const Icon(
                        Icons.visibility_off_outlined,
                        size: 19,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        disabledItemsExpanded
                            ? 'Nascondi piatti disattivati (${inactiveItems.length})'
                            : 'Mostra piatti disattivati (${inactiveItems.length})',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    for (final item in inactiveItems)
                      KeyedSubtree(
                        key: ValueKey('inactive-${item.id}'),
                        child: _buildItemTile(context, item),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, MenuItemModel item) {
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
          PopupMenuButton<String>(
            iconColor: itemActive
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            onSelected: (value) {
              if (itemActive && value == 'edit') {
                _openEditItemDialog(context, item);
              } else if (itemActive && value == 'deactivate') {
                _confirmDeactivateItem(context, item);
              } else if (!itemActive && value == 'reactivate') {
                _reactivateItem(item);
              }
            },
            itemBuilder: (_) => [
              if (itemActive) ...[
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Modifica piatto'),
                ),
                const PopupMenuItem(
                  value: 'deactivate',
                  child: Text('Disattiva piatto'),
                ),
              ] else
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
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.primarySoft,
              checkmarkColor: AppColors.white,
              labelStyle: TextStyle(
                color: selected ? AppColors.white : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: selected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.20),
              ),
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

  int _nextCategorySortOrder(List<MenuCategory> categories) {
    var maximumSortOrder = 0;

    for (final category in categories) {
      if (category.sortOrder > maximumSortOrder) {
        maximumSortOrder = category.sortOrder;
      }
    }

    return maximumSortOrder + 10;
  }

  Future<void> _reorderCategories({
    required List<MenuCategory> allCategories,
    required List<MenuCategory> activeCategories,
    required int oldIndex,
    required int newIndex,
  }) async {
    if (_movingCategory) {
      return;
    }

    final reorderedActiveCategories = List<MenuCategory>.from(activeCategories);

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    if (oldIndex == newIndex) {
      return;
    }

    final movedCategory = reorderedActiveCategories.removeAt(oldIndex);
    reorderedActiveCategories.insert(newIndex, movedCategory);

    final activeCategoryIds = activeCategories
        .map((category) => category.id)
        .toSet();

    var activeIndex = 0;

    final reorderedAllCategories = allCategories.map((category) {
      if (!activeCategoryIds.contains(category.id)) {
        return category;
      }

      final reorderedCategory = reorderedActiveCategories[activeIndex];
      activeIndex += 1;
      return reorderedCategory;
    }).toList();

    setState(() {
      _movingCategory = true;
      _optimisticCategoryOrder = reorderedActiveCategories
          .map((category) => category.id)
          .toList();
    });

    try {
      for (var index = 0; index < reorderedAllCategories.length; index++) {
        final category = reorderedAllCategories[index];

        await ref
            .read(menuCategoriesRepositoryProvider)
            .updateCategory(
              id: category.id,
              name: category.name,
              iconKey: category.iconKey,
              sortOrder: (index + 1) * 10,
            );
      }

      ref.invalidate(menuCategoriesProvider);
      ref.invalidate(allMenuCategoriesProvider);

      await ref.read(allMenuCategoriesProvider.future);

      if (!mounted) {
        return;
      }

      setState(() => _optimisticCategoryOrder = null);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _optimisticCategoryOrder = null);

      AppToast.error(
        context,
        'Impossibile salvare il nuovo ordine delle categorie.',
      );
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
      if (item.categoryId != categoryId || item.id == excludedItemId) {
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
    final reorderedActiveItems = List<MenuItemModel>.from(activeItems);
    final reorderedInactiveItems = List<MenuItemModel>.from(inactiveItems);

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
      _optimisticItemOrderByCategory[categoryId] = reorderedItems
          .map((item) => item.id)
          .toList();
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

      AppToast.error(
        context,
        'Impossibile salvare il nuovo ordine dei piatti.',
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

  Widget _buildCategoryIconSelector({
    required String selectedIconKey,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categoryIconOptions.map((option) {
        final selected = option.key == selectedIconKey;

        return SizedBox(
          width: 64,
          height: 64,
          child: InkWell(
            onTap: () => onSelected(option.key),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                option.icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 28,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openCreateCategoryDialog(BuildContext context) async {
    final categories = await ref.read(allMenuCategoriesProvider.future);
    final menu = await ref.read(currentMenuProvider.future);

    if (!context.mounted) return;

    final nameController = TextEditingController();
    String selectedIconKey = 'restaurant_menu';

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nuova categoria'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Nome'),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Icona',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      _buildCategoryIconSelector(
                        selectedIconKey: selectedIconKey,
                        onSelected: (iconKey) {
                          setState(() => selectedIconKey = iconKey);
                        },
                      ),
                    ],
                  ),
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

                          if (name.isEmpty) return;

                          final sortOrder = _nextCategorySortOrder(categories);

                          setState(() => saving = true);

                          try {
                            await ref
                                .read(menuCategoriesRepositoryProvider)
                                .createCategory(
                                  menuId: menu.id,
                                  name: name,
                                  iconKey: selectedIconKey,
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
    String selectedIconKey = category.iconKey;

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifica categoria'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Nome'),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Icona',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      _buildCategoryIconSelector(
                        selectedIconKey: selectedIconKey,
                        onSelected: (iconKey) {
                          setState(() => selectedIconKey = iconKey);
                        },
                      ),
                    ],
                  ),
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

                          if (name.isEmpty) return;

                          setState(() => saving = true);

                          try {
                            await ref
                                .read(menuCategoriesRepositoryProvider)
                                .updateCategory(
                                  id: category.id,
                                  name: name,
                                  iconKey: selectedIconKey,
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
      AppToast.warning(context, 'Crea prima almeno una categoria');
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
