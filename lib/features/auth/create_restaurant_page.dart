import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_toast.dart';
import 'auth_flow_service.dart';

class CreateRestaurantPage extends ConsumerStatefulWidget {
  const CreateRestaurantPage({super.key});

  @override
  ConsumerState<CreateRestaurantPage> createState() =>
      _CreateRestaurantPageState();
}

class _CreateRestaurantPageState extends ConsumerState<CreateRestaurantPage> {
  final _restaurantNameController = TextEditingController();
  final _restaurantSlugController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _passwordVisible = false;
  bool _hasMangialoQuiAccount = false;
  String? _error;

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _restaurantSlugController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isAlreadyRegistered(AuthException error) {
    final message = error.message.toLowerCase();

    return message.contains('already registered') ||
        message.contains('already been registered') ||
        message.contains('already exists');
  }

  bool _isEmailNotConfirmed(AuthException error) {
    final message = error.message.toLowerCase();

    return message.contains('email not confirmed') ||
        message.contains('not confirmed');
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    AppToast.success(context, message);
  }

  void _showError(String message) {
    if (!mounted) return;
    AppToast.error(context, message);
  }

  void _invalidateRestaurantState({String? selectedRestaurantId}) {
    ref.read(selectedRestaurantIdProvider.notifier).state =
        selectedRestaurantId;
    ref.invalidate(availableRestaurantMembershipsProvider);
    ref.invalidate(currentRestaurantMembershipProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentRestaurantProvider);
    ref.invalidate(currentMenuProvider);
  }

  Future<String?> _createRestaurantForCurrentUser({
    required String restaurantName,
    required String restaurantSlug,
  }) async {
    final result = await ref
        .read(menuProAccountServiceProvider)
        .createMenuProRestaurant(name: restaurantName, slug: restaurantSlug);

    final restaurantId = result['restaurant_id']?.toString().trim() ?? '';

    _invalidateRestaurantState(
      selectedRestaurantId: restaurantId.isEmpty ? null : restaurantId,
    );

    return restaurantId.isEmpty ? null : restaurantId;
  }

  Future<bool> _loginExistingAccountAndCreateRestaurant({
    required String email,
    required String password,
    required String restaurantName,
    required String restaurantSlug,
  }) async {
    final auth = Supabase.instance.client.auth;

    try {
      await auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      if (!_isEmailNotConfirmed(error)) {
        rethrow;
      }

      await auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: AuthFlowService.confirmEmailRedirect,
      );

      AuthFlowService.enterRestaurantEmailConfirmationMode(
        email: email,
        restaurantName: restaurantName,
        restaurantSlug: restaurantSlug,
      );

      if (!mounted) return false;

      context.go(
        Uri(
          path: '/confirm-email',
          queryParameters: {'email': email},
        ).toString(),
      );

      return false;
    }

    await _createRestaurantForCurrentUser(
      restaurantName: restaurantName,
      restaurantSlug: restaurantSlug,
    );

    return true;
  }

  Future<AuthResponse> _signUpForRestaurantCreation({
    required String email,
    required String password,
    required String restaurantName,
    required String restaurantSlug,
  }) async {
    final auth = Supabase.instance.client.auth;

    try {
      return await auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: AuthFlowService.confirmEmailRedirect,
        data: {
          'pending_restaurant_name': restaurantName,
          'pending_restaurant_slug': restaurantSlug,
        },
      );
    } on AuthException catch (error) {
      if (!_isAlreadyRegistered(error)) {
        rethrow;
      }

      throw AuthException(
        'Questa email ha già un account MangialoQui. Attiva "Ho già un account MangialoQui" e inserisci la password.',
      );
    }
  }

  Future<void> _createRestaurant() async {
    final restaurantName = _restaurantNameController.text.trim();
    final restaurantSlug = _restaurantSlugController.text.trim().toLowerCase();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (restaurantName.isEmpty) {
      setState(() => _error = 'Inserisci il nome del ristorante.');
      return;
    }

    if (restaurantSlug.isEmpty) {
      setState(() => _error = 'Inserisci l’indirizzo pubblico del ristorante.');
      return;
    }

    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(restaurantSlug)) {
      setState(
        () => _error =
            'L’indirizzo pubblico può contenere solo lettere minuscole, numeri e trattini.',
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Inserisci una mail valida.');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'La password deve avere almeno 6 caratteri.');
      return;
    }

    if (!_hasMangialoQuiAccount && password != confirmPassword) {
      setState(() => _error = 'Le password non coincidono.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_hasMangialoQuiAccount) {
        final created = await _loginExistingAccountAndCreateRestaurant(
          email: email,
          password: password,
          restaurantName: restaurantName,
          restaurantSlug: restaurantSlug,
        );

        if (!created || !mounted) return;

        _showSuccess('Ristorante creato con successo.');
        context.go('/');
        return;
      }

      final response = await _signUpForRestaurantCreation(
        email: email,
        password: password,
        restaurantName: restaurantName,
        restaurantSlug: restaurantSlug,
      );

      if (!mounted) return;

      AuthFlowService.enterRestaurantEmailConfirmationMode(
        email: email,
        restaurantName: restaurantName,
        restaurantSlug: restaurantSlug,
      );

      final hasSession =
          response.session != null ||
          Supabase.instance.client.auth.currentSession != null;

      if (hasSession) {
        context.go('/complete-restaurant');
        return;
      }

      context.go(
        Uri(
          path: '/confirm-email',
          queryParameters: {'email': email},
        ).toString(),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Errore nella creazione del ristorante.';
      setState(() => _error = message);
      _showError(message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 72,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Crea il tuo ristorante',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Usa questa sezione se vuoi attivare Menu Pro per un nuovo ristorante.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CheckboxListTile(
                      value: _hasMangialoQuiAccount,
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() {
                                _hasMangialoQuiAccount = value ?? false;
                                _error = null;

                                if (_hasMangialoQuiAccount) {
                                  _confirmPasswordController.clear();
                                }
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary,
                      title: const Text('Ho già un account MangialoQui'),
                      subtitle: Text(
                        _hasMangialoQuiAccount
                            ? 'Usa email e password del tuo account esistente.'
                            : 'Lascia disattivato per creare un nuovo account.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _restaurantNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nome ristorante',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _restaurantSlugController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.url,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9-]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Indirizzo pubblico del ristorante',
                        helperText: 'Esempio: nome-ristorante',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      textInputAction: _hasMangialoQuiAccount
                          ? TextInputAction.done
                          : TextInputAction.next,
                      onSubmitted: (_) {
                        if (_hasMangialoQuiAccount && !_loading) {
                          _createRestaurant();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible
                              ? 'Nascondi password'
                              : 'Mostra password',
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                        ),
                      ),
                    ),
                    if (!_hasMangialoQuiAccount) ...[
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !_passwordVisible,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_loading) {
                            _createRestaurant();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Conferma password',
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            tooltip: _passwordVisible
                                ? 'Nascondi password'
                                : 'Mostra password',
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    FilledButton(
                      onPressed: _loading ? null : _createRestaurant,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _hasMangialoQuiAccount
                                  ? 'Accedi e crea il ristorante'
                                  : 'Crea il ristorante',
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: _loading ? null : () => context.go('/login'),
                      child: const Text('Torna al login'),
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

class PendingRestaurantCreationPage extends ConsumerStatefulWidget {
  const PendingRestaurantCreationPage({super.key});

  @override
  ConsumerState<PendingRestaurantCreationPage> createState() =>
      _PendingRestaurantCreationPageState();
}

class _PendingRestaurantCreationPageState
    extends ConsumerState<PendingRestaurantCreationPage> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _completeRestaurantCreation();
  }

  String? _readPendingValue(String key, String? fallback) {
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    final metadataValue = metadata?[key]?.toString().trim();

    if (metadataValue != null && metadataValue.isNotEmpty) {
      return metadataValue;
    }

    final fallbackValue = fallback?.trim();
    if (fallbackValue != null && fallbackValue.isNotEmpty) {
      return fallbackValue;
    }

    return null;
  }

  Future<void> _clearPendingMetadata() async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'pending_restaurant_name': '', 'pending_restaurant_slug': ''},
        ),
      );
    } catch (_) {}
  }

  Future<void> _completeRestaurantCreation() async {
    final restaurantName = _readPendingValue(
      'pending_restaurant_name',
      AuthFlowService.pendingRestaurantName.value,
    );
    final restaurantSlug = _readPendingValue(
      'pending_restaurant_slug',
      AuthFlowService.pendingRestaurantSlug.value,
    );

    if (restaurantName == null || restaurantSlug == null) {
      throw Exception(
        'Dati del ristorante non disponibili. Torna al login e ripeti la procedura.',
      );
    }

    final result = await ref
        .read(menuProAccountServiceProvider)
        .createMenuProRestaurant(name: restaurantName, slug: restaurantSlug);

    final restaurantId = result['restaurant_id']?.toString().trim() ?? '';

    await _clearPendingMetadata();
    AuthFlowService.exitEmailConfirmationMode();

    ref.read(selectedRestaurantIdProvider.notifier).state = restaurantId.isEmpty
        ? null
        : restaurantId;
    ref.invalidate(availableRestaurantMembershipsProvider);
    ref.invalidate(currentRestaurantMembershipProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentRestaurantProvider);
    ref.invalidate(currentMenuProvider);

    if (!mounted) return;
    context.go('/');
  }

  Future<void> _signOut() async {
    AuthFlowService.exitEmailConfirmationMode();

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Sto creando il tuo ristorante...',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Non sono riuscito a creare il ristorante',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _future = _completeRestaurantCreation();
                          });
                        },
                        child: const Text('Riprova'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: _signOut,
                        child: const Text('Esci'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
