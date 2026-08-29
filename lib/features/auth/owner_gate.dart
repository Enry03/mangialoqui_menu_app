import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_toast.dart';
import '../restaurant/restaurant_membership.dart';
import '../restaurant/restaurant_selection_page.dart';
import '../qr/qr_page.dart';

class OwnerGate extends ConsumerWidget {
  final Widget child;

  const OwnerGate({super.key, required this.child});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);

    try {
      await ref.read(supabaseClientProvider).auth.signOut();
      router.go('/login');
    } catch (_) {
      if (!context.mounted) return;
      AppToast.error(context, 'Errore durante la disconnessione.');
    }
  }

  Future<void> _selectRestaurant(
    BuildContext context,
    WidgetRef ref,
    RestaurantMembership membership,
  ) async {
    ref.read(selectedRestaurantIdProvider.notifier).state =
        membership.restaurantId;

    if (!context.mounted) return;
    context.go('/');
  }

  void _chooseAnotherRestaurant(BuildContext context, WidgetRef ref) {
    ref.read(selectedRestaurantIdProvider.notifier).state = null;
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(restaurantMembershipsRealtimeProvider);

    final membershipsAsync = ref.watch(availableRestaurantMembershipsProvider);

    return membershipsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const _LoadingPage(),
      error: (error, stackTrace) {
        if (error.toString().contains('Nessun utente autenticato')) {
          return const _LoadingPage();
        }

        return _AccessPage(
          icon: Icons.error_outline_rounded,
          title: 'Accesso non disponibile',
          message: error.toString().replaceFirst('Exception: ', ''),
          onSignOut: () => _signOut(context, ref),
        );
      },
      data: (memberships) {
        if (memberships.isEmpty) {
          return _AccessPage(
            icon: Icons.error_outline_rounded,
            title: 'Accesso non disponibile',
            message:
                'Nessun ristorante con Menu Pro attivo è disponibile per '
                'questo account.',
            onSignOut: () => _signOut(context, ref),
          );
        }

        if (memberships.length > 1) {
          final selectedRestaurantId = ref.watch(selectedRestaurantIdProvider);
          var hasValidSelection = false;
          for (final membership in memberships) {
            if (membership.restaurantId == selectedRestaurantId) {
              hasValidSelection = true;
              break;
            }
          }

          if (!hasValidSelection) {
            return RestaurantSelectionPage(
              memberships: memberships,
              onSelected: (membership) =>
                  _selectRestaurant(context, ref, membership),
              onSignOut: () => _signOut(context, ref),
            );
          }
        }

        final membershipAsync = ref.watch(currentRestaurantMembershipProvider);

        return membershipAsync.when(
          skipLoadingOnReload: true,
          loading: () => const _LoadingPage(),
          error: (error, stackTrace) {
            if (error.toString().contains('Nessun utente autenticato')) {
              return const _LoadingPage();
            }

            return _AccessPage(
              icon: Icons.error_outline_rounded,
              title: 'Accesso non disponibile',
              message: error.toString().replaceFirst('Exception: ', ''),
              onChooseAnotherRestaurant: memberships.length > 1
                  ? () => _chooseAnotherRestaurant(context, ref)
                  : null,
              onSignOut: () => _signOut(context, ref),
            );
          },
          data: (membership) {
            if (!membership.restaurant.hasMenuPro) {
              return _AccessPage(
                icon: Icons.lock_outline_rounded,
                title: 'Accesso non consentito',
                message: 'Non hai i permessi per usare questa applicazione.',
                onChooseAnotherRestaurant: memberships.length > 1
                    ? () => _chooseAnotherRestaurant(context, ref)
                    : null,
                onSignOut: () => _signOut(context, ref),
              );
            }

            ref.watch(menuProPermissionRealtimeProvider);

            final menuProAccessAsync = ref.watch(currentMenuProAccessProvider);

            return menuProAccessAsync.when(
              skipLoadingOnReload: true,
              loading: () => const _LoadingPage(),
              error: (error, stackTrace) => _AccessPage(
                icon: Icons.error_outline_rounded,
                title: 'Accesso non disponibile',
                message: 'Impossibile verificare i permessi Menu Pro.',
                onChooseAnotherRestaurant: memberships.length > 1
                    ? () => _chooseAnotherRestaurant(context, ref)
                    : null,
                onSignOut: () => _signOut(context, ref),
              ),
              data: (canManageMenuPro) {
                if (!canManageMenuPro) {
                  return QrPage(
                    onChooseAnotherRestaurant: memberships.length > 1
                        ? () => _chooseAnotherRestaurant(context, ref)
                        : null,
                  );
                }

                return child;
              },
            );
          },
        );
      },
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AccessPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onChooseAnotherRestaurant;
  final VoidCallback onSignOut;

  const _AccessPage({
    required this.icon,
    required this.title,
    required this.message,
    this.onChooseAnotherRestaurant,
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
                    Icon(icon, size: 56, color: AppColors.primary),
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
                    if (onChooseAnotherRestaurant != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onChooseAnotherRestaurant,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Scegli un altro ristorante'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
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
