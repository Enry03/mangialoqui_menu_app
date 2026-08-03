import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class OwnerGate extends ConsumerWidget {
  final Widget child;

  const OwnerGate({
    super.key,
    required this.child,
  });

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(supabaseClientProvider).auth.signOut();

      if (!context.mounted) return;
      context.go('/login');
    } catch (_) {
      if (!context.mounted) return;

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

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => _AccessPage(
        icon: Icons.error_outline_rounded,
        title: 'Accesso non disponibile',
        message: error.toString().replaceFirst('Exception: ', ''),
        onSignOut: () => _signOut(context, ref),
      ),
      data: (profile) {
        if (!profile.isOwner) {
          return _AccessPage(
            icon: Icons.lock_outline_rounded,
            title: 'Accesso non consentito',
            message: 'Non hai i permessi per usare questa applicazione.',
            onSignOut: () => _signOut(context, ref),
          );
        }

        final restaurantAsync = ref.watch(currentRestaurantProvider);

        return restaurantAsync.when(
          loading: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stackTrace) => _AccessPage(
            icon: Icons.error_outline_rounded,
            title: 'Accesso non disponibile',
            message: error.toString().replaceFirst('Exception: ', ''),
            onSignOut: () => _signOut(context, ref),
          ),
          data: (restaurant) {
            if (restaurant.hasMenuPro) {
              return child;
            }

            return _AccessPage(
              icon: Icons.lock_outline_rounded,
              title: 'Accesso non consentito',
              message: 'Non hai i permessi per usare questa applicazione.',
              onSignOut: () => _signOut(context, ref),
            );
          },
        );
      },
    );
  }
}

class _AccessPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onSignOut;

  const _AccessPage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 56,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Esci'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
