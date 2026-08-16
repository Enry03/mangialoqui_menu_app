import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/home_action_card.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_items/menu_items_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(currentRestaurantProvider);
    final menuAsync = ref.watch(currentMenuProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTint, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: restaurantAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              if (error.toString().contains('Nessun utente autenticato')) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return Center(
                child: Text('Errore: $error'),
              );
            },
            data: (restaurant) {
              return menuAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, stack) {
                  if (error.toString().contains('Nessun utente autenticato')) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return Center(
                    child: Text('Errore: $error'),
                  );
                },
                data: (_) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xxxl,
                    ),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 18 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroCard(
                            restaurantName: restaurant.name,
                            onOpenSettings: () => context.push('/settings'),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            'Il tuo menu in numeri',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const _StatsRow(),
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            'Gestisci',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _ShortcutsGrid(
                            onOpenMenu: () => context.go('/menu'),
                            onOpenAi: () => context.go('/ai'),
                            onOpenAvailability: () =>
                                context.go('/availability'),
                            onOpenPublish: () => context.push('/more/publish'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String restaurantName;
  final VoidCallback onOpenSettings;

  const _HeroCard({
    required this.restaurantName,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BENVENUTO',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.72),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      restaurantName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.white,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: IconButton(
                  tooltip: 'Impostazioni',
                  onPressed: onOpenSettings,
                  icon: const Icon(
                    Icons.settings_rounded,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);

    final categoriesCount = categoriesAsync.asData?.value.length;
    final items = itemsAsync.asData?.value;
    final itemsCount = items?.length;
    final soldOutCount = items?.where((item) => item.isSoldOut).length;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.folder_open_rounded,
            label: 'Categorie attive',
            value: categoriesCount,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatTile(
            icon: Icons.restaurant_rounded,
            label: 'Piatti attivi',
            value: itemsCount,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatTile(
            icon: Icons.event_busy_rounded,
            label: 'Esauriti',
            value: soldOutCount,
            accent: true,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final bool accent;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ? AppColors.accentDark : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(
            value != null ? '$value' : '–',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 24,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutsGrid extends StatelessWidget {
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenPublish;
  const _ShortcutsGrid({
    required this.onOpenMenu,
    required this.onOpenAi,
    required this.onOpenAvailability,
    required this.onOpenPublish,
  });

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      _ShortcutData(
        icon: Icons.restaurant_menu_rounded,
        title: 'Menù',
        subtitle: 'Categorie e piatti',
        onTap: onOpenMenu,
      ),
      _ShortcutData(
        icon: Icons.auto_awesome_rounded,
        title: 'AI',
        subtitle: 'Modifiche parlate',
        onTap: onOpenAi,
      ),
      _ShortcutData(
        icon: Icons.toggle_on_rounded,
        title: 'Disponibilità',
        subtitle: 'Gestisci i sold out',
        onTap: onOpenAvailability,
      ),
      _ShortcutData(
        icon: Icons.qr_code_2_rounded,
        title: 'QR',
        subtitle: 'QR e link del menu',
        onTap: onOpenPublish,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shortcuts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final data = shortcuts[index];
        return HomeActionCard(
          icon: data.icon,
          title: data.title,
          subtitle: data.subtitle,
          onTap: data.onTap,
          compact: true,
        );
      },
    );
  }
}

class _ShortcutData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShortcutData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
