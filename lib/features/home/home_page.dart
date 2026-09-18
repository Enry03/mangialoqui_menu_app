import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/home_action_card.dart';
import '../../shared/widgets/smooth_dots_loader.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_items/menu_items_provider.dart';

/// Quanto la card statistiche si sovrappone al bordo inferiore dell'header.
const double _kStatsOverlap = 44;

/// Respiro visibile di gradiente tra il nome del ristorante e la card che
/// si sovrappone: evita che il testo sembri "attaccato" alla card bianca.
const double _kHeaderBottomGap = 28;

/// Larghezza massima del contenuto: oltre questa soglia (tablet/desktop)
/// il contenuto resta centrato invece di stirarsi da bordo a bordo.
const double _kContentMaxWidth = 640;

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(currentRestaurantProvider);
    final menuAsync = ref.watch(currentMenuProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: restaurantAsync.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: SmoothDotsLoader()),
        error: (error, stack) {
          if (error.toString().contains('Nessun utente autenticato')) {
            return const Center(child: SmoothDotsLoader());
          }

          return Center(child: Text('Errore: $error'));
        },
        data: (restaurant) {
          return menuAsync.when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: SmoothDotsLoader()),
            error: (error, stack) {
              if (error.toString().contains('Nessun utente autenticato')) {
                return const Center(child: SmoothDotsLoader());
              }

              return Center(child: Text('Errore: $error'));
            },
            data: (_) {
              const reservedGap =
                  _kStatsOverlap + AppSpacing.xxl;

              return Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _HeroHeader(
                        restaurantName: restaurant.name,
                        onOpenSettings: () => context.push('/settings'),
                      ),
                      Positioned(
                        bottom: -_kStatsOverlap,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _kContentMaxWidth,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl,
                              ),
                              child: _StatsCard(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: reservedGap),
                  Expanded(
                    child: Container(
                      color: AppColors.background,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
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
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _kContentMaxWidth,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.xl,
                                  0,
                                  AppSpacing.xl,
                                  AppSpacing.xxxl,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gestisci',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(letterSpacing: -0.3),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    HomeActionCard(
                                      icon: Icons.restaurant_menu_rounded,
                                      title: 'Menù',
                                      subtitle: 'Categorie e piatti',
                                      onTap: () => context.go('/menu'),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _QuickActionsRow(
                                      onOpenAi: () => context.go('/ai'),
                                      onOpenAvailability: () =>
                                          context.go('/availability'),
                                      onOpenQr: () =>
                                          context.push('/more/qr'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String restaurantName;
  final VoidCallback onOpenSettings;

  const _HeroHeader({
    required this.restaurantName,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xl + 8),
          bottomRight: Radius.circular(AppRadius.xl + 8),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40163E78),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.glassHighlight, Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.glassHighlightSoft, Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _kContentMaxWidth,
                ),
                child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                _kStatsOverlap + _kHeaderBottomGap,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.white.withValues(alpha: 0.22),
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
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Bentornato',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.72),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurantName,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: AppColors.white,
                      letterSpacing: -0.8,
                      fontSize: 32,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsCard extends ConsumerWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);

    final categoriesCount = categoriesAsync.asData?.value.length;
    final items = itemsAsync.asData?.value;
    final itemsCount = items?.length;
    final soldOutCount = items?.where((item) => item.isSoldOut).length;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: Offset.zero,
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                icon: Icons.folder_open_rounded,
                value: categoriesCount,
                label: 'Categorie',
              ),
            ),
            VerticalDivider(
              color: AppColors.divider,
              width: 1,
              indent: 4,
              endIndent: 4,
            ),
            Expanded(
              child: _StatItem(
                icon: Icons.restaurant_rounded,
                value: itemsCount,
                label: 'Piatti',
              ),
            ),
            VerticalDivider(
              color: AppColors.divider,
              width: 1,
              indent: 4,
              endIndent: 4,
            ),
            Expanded(
              child: _StatItem(
                icon: Icons.event_busy_rounded,
                value: soldOutCount,
                label: 'Esauriti',
                accent: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final int? value;
  final String label;
  final bool accent;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ? AppColors.accentDark : AppColors.primary;

    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value != null ? '$value' : '–',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 22,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onOpenAi;
  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenQr;

  const _QuickActionsRow({
    required this.onOpenAi,
    required this.onOpenAvailability,
    required this.onOpenQr,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.auto_awesome_rounded,
            label: 'AI',
            tint: AppColors.accentSoft,
            gradient: AppColors.accentGradient,
            onTap: onOpenAi,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.toggle_on_rounded,
            label: 'Disponibilità',
            tint: const Color(0xFFE3F5EA),
            gradient: const [Color(0xFF34AA5D), AppColors.success],
            onTap: onOpenAvailability,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.qr_code_2_rounded,
            label: 'QR',
            tint: AppColors.primaryTintStart,
            gradient: const [AppColors.primaryGlow, AppColors.primary],
            onTap: onOpenQr,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.tint,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: widget.tint,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.gradient,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.gradient.last.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: AppColors.white, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
