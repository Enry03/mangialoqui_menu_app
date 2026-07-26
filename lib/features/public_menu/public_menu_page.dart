import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'public_menu_provider.dart';

class PublicMenuPage extends ConsumerWidget {
  final String restaurantSlug;

  const PublicMenuPage({super.key, required this.restaurantSlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicMenuAsync = ref.watch(publicMenuProvider(restaurantSlug));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: publicMenuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              'Errore caricamento menu: $e',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  'Nessun menù pubblicato per questo ristorante.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  data.menu.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                for (final category in data.categories) ...[
                  Text(category.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Divider(color: AppColors.divider),
                  const SizedBox(height: AppSpacing.xs),
                  ...groupedItems[category.id]!.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
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
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.description != null &&
                                    item.description!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      item.description!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ),
                                if (item.isSoldOut)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Esaurito',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: AppColors.accentDark,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Text(
                            item.formattedPrice,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
