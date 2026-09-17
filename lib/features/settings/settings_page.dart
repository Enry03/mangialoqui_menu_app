import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_toast.dart';
import '../auth/auth_flow_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

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

  Future<void> _disconnectOtherDevices(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Disconnettere gli altri dispositivi?'),
          content: const Text(
            'Verranno disconnessi solo gli altri dispositivi collegati a questo account. Gli altri utenti del ristorante non verranno toccati.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Disconnetti'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await AuthFlowService.requestSignOutOtherDevices();

      if (!context.mounted) return;
      AppToast.success(context, 'Altri dispositivi disconnessi.', flash: true);
    } on AuthException catch (error) {
      if (!context.mounted) return;
      AppToast.error(context, error.message);
    } catch (_) {
      if (!context.mounted) return;
      AppToast.error(
        context,
        'Errore durante la disconnessione degli altri dispositivi.',
      );
    }
  }

  void _changeRestaurant(BuildContext context, WidgetRef ref) {
    ref.read(selectedRestaurantIdProvider.notifier).state = null;
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final restaurantAsync = ref.watch(currentRestaurantProvider);
    final membershipsAsync = ref.watch(availableRestaurantMembershipsProvider);
    final canChangeRestaurant = membershipsAsync.maybeWhen(
      data: (memberships) => memberships.length > 1,
      orElse: () => false,
    );
    final user = ref.watch(supabaseClientProvider).auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTint, AppColors.background],
          ),
        ),
        child: SafeArea(
          top: false,
          child: profileAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
            data: (profile) {
              return restaurantAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text(error.toString().replaceFirst('Exception: ', '')),
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
                          Divider(height: 1, color: AppColors.divider),
                          _SettingsInfoRow(label: 'User ID', value: profile.id),
                          Divider(height: 1, color: AppColors.divider),
                          _SettingsInfoRow(
                            label: 'Ruolo',
                            value: profile.isOwner ? 'Proprietario' : profile.role,
                          ),
                          Divider(height: 1, color: AppColors.divider),
                          _SettingsActionRow(
                            icon: Icons.devices_other_rounded,
                            label: 'Disconnetti altri dispositivi',
                            onTap: () => _disconnectOtherDevices(context),
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
                          Divider(height: 1, color: AppColors.divider),
                          _SettingsInfoRow(
                            label: 'Restaurant ID',
                            value: restaurant.id,
                          ),
                          Divider(height: 1, color: AppColors.divider),
                          _SettingsInfoRow(
                            label: 'Menu Pro',
                            value: restaurant.hasMenuPro
                                ? 'Attivo'
                                : 'Non attivo',
                            highlighted: restaurant.hasMenuPro,
                          ),
                          if (profile.isOwner) ...[
                            Divider(height: 1, color: AppColors.divider),
                            _SettingsActionRow(
                              icon: Icons.manage_accounts_outlined,
                              label: 'Gestione accessi',
                              onTap: () => context.push('/settings/access'),
                            ),
                          ],
                          if (canChangeRestaurant) ...[
                            Divider(height: 1, color: AppColors.divider),
                            _SettingsActionRow(
                              icon: Icons.swap_horiz_rounded,
                              label: 'Cambia ristorante',
                              onTap: () => _changeRestaurant(context, ref),
                            ),
                          ],
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

class AccessManagementPage extends ConsumerStatefulWidget {
  const AccessManagementPage({super.key});

  @override
  ConsumerState<AccessManagementPage> createState() =>
      _AccessManagementPageState();
}

class _AccessManagementPageState extends ConsumerState<AccessManagementPage> {
  bool _loading = true;
  bool _saving = false;
  bool _isOwner = false;
  String? _restaurantId;
  String? _currentUserEmail;
  String? _primaryOwnerUserId;
  List<Map<String, dynamic>> _people = const [];

  RealtimeChannel? _accessManagementRealtimeChannel;
  String? _accessManagementRealtimeRestaurantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _accessManagementRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _ensureAccessManagementRealtime(String restaurantId) async {
    if (_accessManagementRealtimeChannel != null &&
        _accessManagementRealtimeRestaurantId == restaurantId) {
      return;
    }

    await _accessManagementRealtimeChannel?.unsubscribe();

    if (!mounted) return;

    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id ?? 'unknown';

    _accessManagementRealtimeRestaurantId = restaurantId;

    _accessManagementRealtimeChannel = client
        .channel('menu-pro-access-management-$userId-$restaurantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'restaurant_allowed_emails',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: restaurantId,
          ),
          callback: (_) {
            if (!mounted) return;

            _load(showPageLoader: false);
          },
        )
        .subscribe();
  }

  Future<void> _load({bool showPageLoader = true}) async {
    if (mounted && showPageLoader) {
      setState(() => _loading = true);
    }

    try {
      final membership = await ref.read(
        currentRestaurantMembershipProvider.future,
      );

      if (!membership.isOwner) {
        await _accessManagementRealtimeChannel?.unsubscribe();
        _accessManagementRealtimeChannel = null;
        _accessManagementRealtimeRestaurantId = null;

        if (!mounted) return;

        setState(() {
          _isOwner = false;
          _loading = false;
          _restaurantId = membership.restaurantId;
          _primaryOwnerUserId = membership.restaurant.ownerUserId;
          _people = const [];
        });
        return;
      }

      await _ensureAccessManagementRealtime(membership.restaurantId);

      if (!mounted) return;

      final rows = await ref
          .read(menuProAccountServiceProvider)
          .loadAllowedEmails(restaurantId: membership.restaurantId);

      final currentUser = ref.read(supabaseClientProvider).auth.currentUser;

      final currentEmail = currentUser?.email?.trim().toLowerCase();

      if (!mounted) return;

      setState(() {
        _isOwner = true;
        _restaurantId = membership.restaurantId;
        _currentUserEmail = currentEmail;
        _primaryOwnerUserId = membership.restaurant.ownerUserId;

        _people = rows.where((row) {
          if (currentUser?.id != membership.restaurant.ownerUserId) {
            return true;
          }

          final email = ((row['email'] as String?) ?? '').trim().toLowerCase();

          return email.isEmpty || email != currentEmail;
        }).toList();

        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showError('Errore nel caricamento della gestione accessi.');
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    AppToast.success(context, message);
  }

  void _showWarning(String message) {
    if (!mounted) return;
    AppToast.warning(context, message);
  }

  void _showError(String message) {
    if (!mounted) return;
    AppToast.error(context, message);
  }

  String _formatCreatedAt(dynamic raw) {
    if (raw == null) return 'Data non disponibile';

    final date = DateTime.tryParse(raw.toString());

    if (date == null) return 'Data non disponibile';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _roleLabel(String role) {
    return role == 'owner' ? 'Proprietario' : 'Staff';
  }

  String _roleActionLabel(String role) {
    return role == 'owner' ? 'Rendi staff' : 'Rendi proprietario';
  }

  Future<bool> _confirmRemoval(String email) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("Rimuovere l'accesso?"),
            content: Text('$email non potrà più accedere a questo ristorante.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Rimuovi'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmRoleChange(String newRole) async {
    final message = newRole == 'owner'
        ? 'Questa persona diventerà proprietario di questo ristorante.'
        : 'Questa persona diventerà staff di questo ristorante.';

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confermi il cambio ruolo?'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Conferma'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _addPerson() async {
    if (_saving || _restaurantId == null) return;

    final fullNameController = TextEditingController();

    final emailController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aggiungi persona autorizzata'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'La persona verrà aggiunta come staff. Potrai cambiarla in proprietario dalla lista.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: fullNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nome e cognome'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final fullName = fullNameController.text.trim();
              final email = emailController.text.trim().toLowerCase();

              if (fullName.isEmpty) {
                _showWarning('Inserisci nome e cognome.');
                return;
              }

              final validEmail = RegExp(
                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
              ).hasMatch(email);

              if (!validEmail) {
                _showWarning('Inserisci un indirizzo email valido.');
                return;
              }

              if (email == (_currentUserEmail ?? '')) {
                _showWarning('Non puoi aggiungere la tua stessa email.');
                return;
              }

              Navigator.pop(dialogContext, true);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (!mounted) {
      fullNameController.dispose();
      emailController.dispose();
      return;
    }

    if (confirmed != true) {
      fullNameController.dispose();
      emailController.dispose();
      return;
    }

    final fullName = fullNameController.text.trim();

    final email = emailController.text.trim().toLowerCase();

    fullNameController.dispose();
    emailController.dispose();

    if (fullName.isEmpty) {
      _showWarning('Inserisci nome e cognome.');
      return;
    }

    final validEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

    if (!validEmail) {
      _showWarning('Inserisci un indirizzo email valido.');
      return;
    }

    if (email == (_currentUserEmail ?? '')) {
      _showWarning('Non puoi aggiungere la tua stessa email.');
      return;
    }

    setState(() => _saving = true);

    try {
      await ref
          .read(menuProAccountServiceProvider)
          .addAllowedEmail(
            restaurantId: _restaurantId!,
            fullName: fullName,
            email: email,
          );

      if (!mounted) return;

      _showSuccess('Persona autorizzata salvata.');

      await _load(showPageLoader: false);
    } catch (_) {
      if (!mounted) return;

      _showError('Errore durante il salvataggio della persona.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _removePerson(Map<String, dynamic> row) async {
    if (_saving || _restaurantId == null) return;

    final email = ((row['email'] as String?) ?? '').trim().toLowerCase();

    if (email.isEmpty) return;

    final confirmed = await _confirmRemoval(email);

    if (!confirmed) return;

    setState(() => _saving = true);

    try {
      await ref
          .read(menuProAccountServiceProvider)
          .removeAllowedEmail(restaurantId: _restaurantId!, email: email);

      if (!mounted) return;

      _showSuccess('Accesso rimosso.');

      await _load(showPageLoader: false);
    } catch (_) {
      if (!mounted) return;

      _showError("Errore durante la rimozione dell'accesso.");
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleRole(Map<String, dynamic> row) async {
    if (_saving || _restaurantId == null) return;

    final email = ((row['email'] as String?) ?? '').trim().toLowerCase();

    final currentRole = ((row['desired_role'] as String?) ?? 'staff')
        .trim()
        .toLowerCase();

    if (email.isEmpty) return;

    if (email == (_currentUserEmail ?? '')) {
      _showWarning('Non puoi cambiare il tuo ruolo da questa schermata.');
      return;
    }

    final newRole = currentRole == 'owner' ? 'staff' : 'owner';

    final confirmed = await _confirmRoleChange(newRole);

    if (!confirmed) return;

    setState(() => _saving = true);

    try {
      await ref
          .read(menuProAccountServiceProvider)
          .updateAllowedEmailRole(
            restaurantId: _restaurantId!,
            email: email,
            desiredRole: newRole,
          );

      if (!mounted) return;

      _showSuccess('Ruolo aggiornato.');

      await _load(showPageLoader: false);
    } catch (_) {
      if (!mounted) return;

      _showError('Errore durante il cambio ruolo.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _setMenuProPermission(
    Map<String, dynamic> row,
    bool canManage,
  ) async {
    if (_saving || _restaurantId == null) return;

    final email = ((row['email'] as String?) ?? '').trim().toLowerCase();

    final role = ((row['desired_role'] as String?) ?? 'staff')
        .trim()
        .toLowerCase();

    if (email.isEmpty || role != 'staff') return;

    setState(() => _saving = true);

    try {
      await ref
          .read(menuProAccountServiceProvider)
          .setMenuProPermission(
            restaurantId: _restaurantId!,
            email: email,
            canManage: canManage,
          );

      if (!mounted) return;

      _showSuccess(
        canManage
            ? 'Permesso Menu Pro abilitato.'
            : 'Permesso Menu Pro disabilitato.',
      );

      await _load(showPageLoader: false);
    } catch (_) {
      if (!mounted) return;

      _showError('Errore durante la modifica del permesso Menu Pro.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _roleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Text(
        _roleLabel(role),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _primaryOwnerCard() {
    final currentUser = ref.read(supabaseClientProvider).auth.currentUser;

    final isCurrentUser = currentUser?.id == _primaryOwnerUserId;

    final email = isCurrentUser ? currentUser?.email?.trim() : null;

    return _AccessPersonCard(
      name: isCurrentUser
          ? 'Proprietario principale (tu)'
          : 'Proprietario principale',
      email: email == null || email.isEmpty
          ? 'Proprietario principale del ristorante'
          : email,
      subtitle: 'Accesso principale del ristorante',
      badge: _roleBadge('owner'),
      actions: const [],
    );
  }

  Widget _personCard(Map<String, dynamic> row) {
    final fullNameRaw = (row['full_name'] as String?) ?? '';

    final fullName = fullNameRaw.trim().isEmpty
        ? 'Nome non inserito'
        : fullNameRaw.trim();

    final email = ((row['email'] as String?) ?? '').trim();

    final role = ((row['desired_role'] as String?) ?? 'staff')
        .trim()
        .toLowerCase();

    final isSelf = email.toLowerCase() == (_currentUserEmail ?? '');

    final canManageMenuPro = row['can_manage_menu_pro'] == true;

    return _AccessPersonCard(
      name: fullName,
      email: email.isEmpty ? 'Email non disponibile' : email,
      subtitle: 'Aggiunta il ${_formatCreatedAt(row['created_at'])}',
      badge: _roleBadge(role),
      permissionControl: role == 'staff'
          ? SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                canManageMenuPro
                    ? 'Questo utente può modificare il menu.'
                    : 'Questo utente non può modificare il menu.',
              ),
              value: canManageMenuPro,
              onChanged: _saving
                  ? null
                  : (value) => _setMenuProPermission(row, value),
            )
          : null,
      actions: [
        FilledButton.tonal(
          onPressed: _saving || isSelf ? null : () => _toggleRole(row),
          child: Text(_roleActionLabel(role)),
        ),
        OutlinedButton.icon(
          onPressed: _saving ? null : () => _removePerson(row),
          icon: const Icon(Icons.person_remove_outlined),
          label: const Text('Rimuovi'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestione accessi')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTint, AppColors.background],
          ),
        ),
        child: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : !_isOwner
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'Questa sezione è disponibile solo ai proprietari del ristorante.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xl,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Utenti autorizzati',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      'Gestisci chi può usare l\'app e chi può modificare il menu.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    FilledButton.icon(
                                      onPressed: _saving ? null : _addPerson,
                                      icon: const Icon(
                                        Icons.person_add_alt_1_rounded,
                                      ),
                                      label: const Text('Aggiungi persona'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _primaryOwnerCard(),
                              if (_people.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                ..._people.map(
                                  (row) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.md,
                                    ),
                                    child: _personCard(row),
                                  ),
                                ),
                              ],
                            ],
                          ),
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

class _AccessPersonCard extends StatelessWidget {
  final String name;
  final String email;
  final String subtitle;
  final Widget badge;
  final Widget? permissionControl;
  final List<Widget> actions;

  const _AccessPersonCard({
    required this.name,
    required this.email,
    required this.subtitle,
    required this.badge,
    this.permissionControl,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          badge,
          if (permissionControl != null) ...[
            const SizedBox(height: AppSpacing.md),
            permissionControl!,
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: actions,
            ),
          ],
        ],
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
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
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
                color: highlighted ? AppColors.primary : AppColors.textPrimary,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
