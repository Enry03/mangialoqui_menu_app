import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/home_action_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(supabaseClientProvider).auth.signOut();

      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentRestaurantProvider);
      ref.invalidate(currentMenuProvider);
      ref.invalidate(currentThemeProvider);

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
    final restaurantAsync = ref.watch(currentRestaurantProvider);
    final menuAsync = ref.watch(currentMenuProvider);

    return restaurantAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Errore: $error'))),
      data: (restaurant) {
        return menuAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) =>
              Scaffold(body: Center(child: Text('Errore: $error'))),
          data: (menu) {
            return AppShell(
              title: restaurant.name,
              subtitle: 'Menu attivo: ${menu.name}',
              action: IconButton(
                tooltip: 'Esci',
                onPressed: () => _signOut(context, ref),
                icon: const Icon(Icons.logout_rounded),
              ),
              child: Column(
                children: [
                  HomeActionCard(
                    icon: Icons.restaurant_menu_rounded,
                    title: 'Menu',
                    subtitle: 'Categorie, piatti e modifiche manuali.',
                    onTap: () => context.push('/menu'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HomeActionCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI',
                    subtitle:
                        'Modifiche al menu con richieste in linguaggio naturale.',
                    onTap: () => context.push('/ai'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HomeActionCard(
                    icon: Icons.toggle_on_rounded,
                    title: 'Disponibilità',
                    subtitle: 'Gestisci sold out e disponibilità dei piatti.',
                    onTap: () => context.push('/availability'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HomeActionCard(
                    icon: Icons.public_rounded,
                    title: 'Pubblica',
                    subtitle: 'Controlla stato del menu e versione pubblicata.',
                    onTap: () => context.push('/publish'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HomeActionCard(
                    icon: Icons.palette_outlined,
                    title: 'Aspetto',
                    subtitle: 'Font, colori, tema e identità visiva.',
                    onTap: () => context.push('/appearance'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
