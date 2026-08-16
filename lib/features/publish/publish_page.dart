import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../menu/menu.dart';

class PublishPage extends ConsumerStatefulWidget {
  const PublishPage({super.key});

  @override
  ConsumerState<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends ConsumerState<PublishPage> {
  bool _showQrCode = false;
  bool _savingQr = false;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    final restaurantAsync = ref.watch(currentRestaurantProvider);
    final menuAsync = ref.watch(currentMenuProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR'),
        actions: [
          IconButton(
            tooltip: 'Esci',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTint, AppColors.background],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              restaurantAsync.when(
                data: (restaurant) => menuAsync.when(
                  data: (menu) => _HeaderPreview(
                    restaurantSlug: restaurant.slug,
                    menu: menu,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Errore menu: $e'),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Errore ristorante: $e'),
              ),
              const SizedBox(height: AppSpacing.xxl),
              restaurantAsync.when(
                data: (restaurant) => _QrCodeSection(
                  restaurantSlug: restaurant.slug,
                  showQrCode: _showQrCode,
                  savingQr: _savingQr,
                  screenshotController: _screenshotController,
                  onGenerate: () {
                    setState(() {
                      _showQrCode = true;
                    });
                  },
                  onShare: () => _sharePublicMenuLink(restaurant.slug),
                  onSave: () => _saveQrCodeToGallery(restaurant.slug),
                  onOpen: () => _openPublicMenu(restaurant.slug),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Errore QR code: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(supabaseClientProvider).auth.signOut();
      router.go('/login');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Errore durante la disconnessione.')),
      );
    }
  }

  String _publicMenuUrl(String slug) {
    return 'https://$slug.mangialoqui.it/menu';
  }

  Future<void> _openPublicMenu(String slug) async {
    try {
      final uri = Uri.parse(_publicMenuUrl(slug));
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il menu pubblico')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore apertura menu: $e')));
      }
    }
  }

  Future<void> _sharePublicMenuLink(String slug) async {
    try {
      final url = _publicMenuUrl(slug);
      await Share.share(
        'Ecco il menu del ristorante:\n$url',
        subject: 'Menu pubblico',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore condivisione: $e')));
      }
    }
  }

  Future<void> _saveQrCodeToGallery(String slug) async {
    try {
      setState(() {
        _savingQr = true;
      });

      if (!_showQrCode) {
        setState(() {
          _showQrCode = true;
        });
        await Future.delayed(const Duration(milliseconds: 150));
      }

      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
      );

      if (imageBytes == null) {
        throw Exception('Impossibile generare l’immagine del QR code');
      }

      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        quality: 100,
        name: 'menu_qr_$slug',
      );

      final success =
          result is Map &&
          (result['isSuccess'] == true || result['success'] == true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'QR code salvato sul telefono'
                  : 'Salvataggio non riuscito',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore salvataggio QR: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingQr = false;
        });
      }
    }
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;

  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}

class _HeaderPreview extends StatelessWidget {
  final String restaurantSlug;
  final MenuModel menu;

  const _HeaderPreview({required this.restaurantSlug, required this.menu});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Uri publicUrl = Uri.parse(
      'https://$restaurantSlug.mangialoqui.it/menu',
    );

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menu pubblico',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(menu.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  publicUrl.toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  await launchUrl(
                    publicUrl,
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Apri'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrCodeSection extends StatelessWidget {
  final String restaurantSlug;
  final bool showQrCode;
  final bool savingQr;
  final ScreenshotController screenshotController;
  final VoidCallback onGenerate;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  const _QrCodeSection({
    required this.restaurantSlug,
    required this.showQrCode,
    required this.savingQr,
    required this.screenshotController,
    required this.onGenerate,
    required this.onShare,
    required this.onSave,
    required this.onOpen,
  });

  String get _qrUrl => 'https://$restaurantSlug.mangialoqui.it/menu';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QR code del menu', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Questo QR code è unico per il ristorante e resta sempre lo stesso. '
            'Se il menu cambia, il QR non cambia.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!showQrCode)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Genera QR code'),
              ),
            ),
          if (showQrCode) ...[
            Center(
              child: Screenshot(
                controller: screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: _qrUrl,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: AppColors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.primary,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 240,
                        child: Text(
                          _qrUrl,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Condividi link'),
                ),
                OutlinedButton.icon(
                  onPressed: savingQr ? null : onSave,
                  icon: savingQr
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    savingQr ? 'Salvataggio...' : 'Salva sul telefono',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Apri menu'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
