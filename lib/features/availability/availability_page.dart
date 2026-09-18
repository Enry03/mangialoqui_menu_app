import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/responsive_content.dart';
import '../../shared/widgets/smooth_dots_loader.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_categories/menu_category.dart';
import '../menu_items/menu_item.dart';
import '../menu_items/menu_items_provider.dart';

class AvailabilityPage extends ConsumerWidget {
  const AvailabilityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        titleSpacing: 18,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.20),
                ),
              ),
              child: const Icon(
                Icons.toggle_on_rounded,
                color: AppColors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DISPONIBILITÀ',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.72),
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Stato dei piatti',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTint, AppColors.background],
          ),
        ),
        child: ResponsiveContent(
          child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: categoriesAsync.when(
            data: (categories) {
              return itemsAsync.when(
                data: (items) {
                  if (categories.isEmpty || items.isEmpty) {
                    return const _EmptyAvailabilityView();
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
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
                loading: () => const Center(child: SmoothDotsLoader()),
                error: (e, _) => Center(child: Text('Errore piatti: $e')),
              );
            },
            loading: () => const Center(child: SmoothDotsLoader()),
            error: (e, _) => Center(child: Text('Errore categorie: $e')),
          ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAvailabilityView extends StatelessWidget {
  const _EmptyAvailabilityView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryTintStart,
                    AppColors.primaryTintEnd,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nessun piatto ancora',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Aggiungi piatti dalla pagina Menù per gestire qui il sold out.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        title: Text(
          category.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
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
          ...items.map(
            (item) => _AvailabilityItemRow(
              key: ValueKey(item.id),
              item: item,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityItemRow extends ConsumerStatefulWidget {
  final MenuItemModel item;

  const _AvailabilityItemRow({super.key, required this.item});

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
  void didUpdateWidget(covariant _AvailabilityItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.item.isSoldOut != widget.item.isSoldOut) {
      isSoldOut = widget.item.isSoldOut;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: theme.textTheme.titleMedium?.copyWith(
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  widget.item.formattedPrice,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSoldOut
                        ? AppColors.accentSoft
                        : AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    isSoldOut ? 'Sold out' : 'Disponibile',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSoldOut
                          ? AppColors.accentDark
                          : AppColors.success,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: isSoldOut,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.accent,
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
                      ref.invalidate(allMenuItemsProvider);

                      if (context.mounted) {
                        AppToast.success(
                          context,
                          value
                              ? '${widget.item.name} segnato come sold out'
                              : '${widget.item.name} di nuovo disponibile',
                        );
                      }
                    } catch (e) {
                      setState(() {
                        isSoldOut = !value;
                      });

                      if (context.mounted) {
                        AppToast.error(context, 'Errore: $e');
                      }
                    } finally {
                      if (mounted) {
                        setState(() => isSaving = false);
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }
}
