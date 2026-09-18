import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../shared/widgets/app_toast.dart';

Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Vuoi uscire?'),
        content: const Text(
          'Dovrai effettuare nuovamente l’accesso per utilizzare l’app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Esci'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  await _performSignOut(context, ref);
}

Future<void> _performSignOut(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);

  ref.read(selectedRestaurantIdProvider.notifier).state = null;
  ref.read(lastCurrentRestaurantIdProvider.notifier).state = null;
  ref.read(currentRestaurantRemovedProvider.notifier).state = false;
  ref.read(currentRestaurantMenuProDisabledProvider.notifier).state = false;

  try {
    await ref.read(supabaseClientProvider).auth.signOut();
    router.go('/login');
  } catch (_) {
    if (!context.mounted) return;
    AppToast.error(context, 'Errore durante la disconnessione.');
  }
}
