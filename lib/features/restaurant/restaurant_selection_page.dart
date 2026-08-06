import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'restaurant_membership.dart';

class RestaurantSelectionPage extends StatefulWidget {
  final List<RestaurantMembership> memberships;
  final Future<void> Function(RestaurantMembership membership) onSelected;
  final Future<void> Function() onSignOut;

  const RestaurantSelectionPage({
    super.key,
    required this.memberships,
    required this.onSelected,
    required this.onSignOut,
  });

  @override
  State<RestaurantSelectionPage> createState() =>
      _RestaurantSelectionPageState();
}

class _RestaurantSelectionPageState extends State<RestaurantSelectionPage> {
  String? _selectingRestaurantId;
  bool _signingOut = false;

  bool get _isBusy => _selectingRestaurantId != null || _signingOut;

  Future<void> _select(RestaurantMembership membership) async {
    if (_isBusy) {
      return;
    }

    setState(() => _selectingRestaurantId = membership.restaurantId);
    try {
      await widget.onSelected(membership);
    } finally {
      if (mounted) {
        setState(() => _selectingRestaurantId = null);
      }
    }
  }

  Future<void> _signOut() async {
    if (_isBusy) {
      return;
    }

    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  String _restaurantName(RestaurantMembership membership) {
    final name = membership.restaurant.name.trim();
    return name.isEmpty ? 'Ristorante senza nome' : name;
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'staff':
        return 'Staff';
      default:
        final normalizedRole = role.trim();
        return normalizedRole.isEmpty ? 'Ruolo non disponibile' : role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xxxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Scegli il ristorante',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Questo account è collegato a più ristoranti. '
                      'Seleziona quello che vuoi gestire adesso.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    ...widget.memberships.map(
                      (membership) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _RestaurantCard(
                          name: _restaurantName(membership),
                          role: _roleLabel(membership.role),
                          loading: _selectingRestaurantId ==
                              membership.restaurantId,
                          enabled: !_isBusy,
                          onTap: () => _select(membership),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _signOut,
                      icon: _signingOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout_rounded),
                      label: const Text('Esci'),
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

class _RestaurantCard extends StatelessWidget {
  final String name;
  final String role;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  const _RestaurantCard({
    required this.name,
    required this.role,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      role,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
