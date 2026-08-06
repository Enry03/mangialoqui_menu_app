import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'auth_flow_service.dart';

class ConfirmEmailPage extends StatefulWidget {
  final String email;

  const ConfirmEmailPage({
    super.key,
    required this.email,
  });

  @override
  State<ConfirmEmailPage> createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends State<ConfirmEmailPage> {
  StreamSubscription<AuthState>? _authSubscription;

  bool _loading = false;
  bool _confirmed = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final currentUser = Supabase.instance.client.auth.currentUser;
    _confirmed = currentUser?.emailConfirmedAt != null;

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final isConfirmed = session?.user.emailConfirmedAt != null;

      if (!mounted || !isConfirmed) {
        return;
      }

      setState(() {
        _confirmed = true;
        _error = null;
      });

      final metadata = session?.user.userMetadata;
      final pendingName =
          metadata?['pending_restaurant_name']?.toString().trim() ?? '';
      final pendingSlug =
          metadata?['pending_restaurant_slug']?.toString().trim() ?? '';

      if (pendingName.isNotEmpty && pendingSlug.isNotEmpty) {
        context.go('/complete-restaurant');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resendConfirmationEmail() async {
    if (_loading) return;

    final email = widget.email.trim().toLowerCase();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Email non valida');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: AuthFlowService.confirmEmailRedirect,
      );

      if (!mounted) return;
      _showMessage('Email di conferma inviata di nuovo');
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Errore durante il reinvio della conferma.';
      setState(() => _error = message);
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _backToLogin() async {
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
    final email = widget.email.trim().isNotEmpty
        ? widget.email.trim()
        : AuthFlowService.pendingConfirmationEmail.value ?? '';

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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      _confirmed
                          ? Icons.mark_email_read_rounded
                          : Icons.mark_email_unread_outlined,
                      size: 72,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _confirmed
                          ? 'Email confermata'
                          : 'Controlla la tua email',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _confirmed
                          ? 'La tua email è stata confermata correttamente.'
                          : 'Apri il messaggio ricevuto e conferma il tuo account MangialoQui.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!_confirmed && email.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _backToLogin,
                        child: Text(
                          _confirmed ? 'Continua' : 'Torna al login',
                        ),
                      ),
                    ),
                    if (!_confirmed) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed:
                            _loading ? null : _resendConfirmationEmail,
                        child: const Text(
                          'Non hai ricevuto l’email? Reinvia',
                        ),
                      ),
                    ],
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
