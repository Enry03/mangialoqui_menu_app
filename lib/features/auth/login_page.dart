import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'auth_flow_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _passwordVisible = false;
  bool _showResendConfirmation = false;
  bool _resendingConfirmation = false;
  String? _error;

  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Inserisci email e password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _showResendConfirmation = false;
    });

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        _showError('Credenziali non valide');
        return;
      }

      ref.read(selectedRestaurantIdProvider.notifier).state = null;
      ref.invalidate(availableRestaurantMembershipsProvider);
      ref.invalidate(currentRestaurantMembershipProvider);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentRestaurantProvider);
      ref.invalidate(currentMenuProvider);
      ref.invalidate(currentThemeProvider);

      if (!mounted) return;
      context.go('/');
    } on AuthException catch (error) {
      if (!mounted) return;

      if (error.message.toLowerCase().contains('email not confirmed')) {
        setState(() {
          _error = 'Devi prima confermare la tua email per accedere.';
          _showResendConfirmation = true;
        });
        _showError('Email non confermata');
        return;
      }

      setState(() {
        _error = error.message;
        _showResendConfirmation = false;
      });
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Errore di accesso. Riprova.';
      setState(() => _error = message);
      _showError(message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resendConfirmationEmail() async {
    if (_loading || _resendingConfirmation) return;

    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty || !email.contains('@')) {
      _showError('Inserisci una mail valida');
      return;
    }

    setState(() {
      _resendingConfirmation = true;
      _error = null;
    });

    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: AuthFlowService.confirmEmailRedirect,
      );

      if (!mounted) return;

      setState(() {
        _error = 'Email di conferma inviata di nuovo. Controlla la posta.';
      });
      _showError('Email di conferma inviata di nuovo');
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Errore durante il reinvio della conferma.';
      setState(() => _error = message);
      _showError(message);
    } finally {
      if (mounted) {
        setState(() => _resendingConfirmation = false);
      }
    }
  }

  Future<void> _openResetPasswordDialog() async {
    if (_loading) return;

    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reimposta password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Inserisci la tua email. Riceverai un messaggio per impostare una nuova password.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(emailController.text.trim());
              },
              child: const Text('Invia'),
            ),
          ],
        );
      },
    );

    emailController.dispose();

    if (!mounted || result == null) return;

    final email = result.trim().toLowerCase();

    if (email.isEmpty || !email.contains('@')) {
      _showError('Inserisci una mail valida');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: AuthFlowService.resetPasswordRedirect,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Email inviata'),
            content: const Text(
              'Se questa mail è collegata a un account, riceverai un messaggio per reimpostare la password.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Ho capito'),
              ),
            ],
          );
        },
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Errore durante il reset password.';
      setState(() => _error = message);
      _showError(message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.10),
                        ),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Mangialoqui Menù',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Accedi per gestire il menù del tuo ristorante.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_loading) {
                                _signIn();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : _openResetPasswordDialog,
                              child: const Text('Password dimenticata?'),
                            ),
                          ),
                          if (_error != null) ...[
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (_showResendConfirmation) ...[
                            OutlinedButton(
                              onPressed: _resendingConfirmation
                                  ? null
                                  : _resendConfirmationEmail,
                              child: _resendingConfirmation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Reinvia email di conferma',
                                    ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          FilledButton(
                            onPressed: _loading ? null : _signIn,
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('Accedi'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => context.push('/register'),
                            child: const Text('Registrati'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextButton.icon(
                            onPressed: _loading
                                ? null
                                : () => context.push('/create-restaurant'),
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text(
                              'Crea il tuo ristorante',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Usa le stesse credenziali che utilizzi per la piattaforma web.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: AppColors.textMuted,
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
