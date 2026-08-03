import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref.read(supabaseClientProvider).auth.signOut();

      if (!context.mounted) {
        return;
      }

      context.go('/login');
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore durante la disconnessione.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final restaurantAsync = ref.watch(currentRestaurantProvider);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundTint,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: profileAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) => Center(
              child: Text(
                error.toString().replaceFirst('Exception: ', ''),
              ),
            ),
            data: (profile) {
              return restaurantAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => Center(
                  child: Text(
                    error.toString().replaceFirst('Exception: ', ''),
                  ),
                ),
                data: (restaurant) {
                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      _SettingsSection(
                        title: 'Account',
                        icon: Icons.person_outline_rounded,
                        children: [
                          _SettingsInfoRow(
                            label: 'Email',
                            value: user?.email ?? 'Non disponibile',
                          ),
                          const Divider(height: 1),
                          _SettingsInfoRow(
                            label: 'User ID',
                            value: profile.id,
                          ),
                          const Divider(height: 1),
                          _SettingsInfoRow(
                            label: 'Ruolo',
                            value: profile.isOwner ? 'Owner' : profile.role,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SettingsSection(
                        title: 'Ristorante',
                        icon: Icons.storefront_outlined,
                        children: [
                          _SettingsInfoRow(
                            label: 'Nome',
                            value: restaurant.name,
                          ),
                          const Divider(height: 1),
                          _SettingsInfoRow(
                            label: 'Restaurant ID',
                            value: restaurant.id,
                          ),
                          const Divider(height: 1),
                          _SettingsInfoRow(
                            label: 'Menu Pro',
                            value: restaurant.hasMenuPro
                                ? 'Attivo'
                                : 'Non attivo',
                            highlighted: restaurant.hasMenuPro,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _signOut(context, ref),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Esci'),
                        ),
                      ),
                    ],
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

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: AppColors.divider,
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;

  const _SettingsInfoRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: highlighted
                    ? AppColors.primary
                    : AppColors.textPrimary,
                fontWeight: highlighted
                    ? FontWeight.w700
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}