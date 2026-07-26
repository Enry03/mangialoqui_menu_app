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
import '../menu_categories/menu_categories_provider.dart';
import '../menu_items/menu_items_provider.dart';
import 'menu_publish_provider.dart';
import 'menu_publish_repository.dart';

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
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);
    final versionsAsync = ref.watch(menuVersionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pubblica'),
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
              const SizedBox(height: AppSpacing.xxl),
              _SectionTitle('Anteprima menu pubblico'),
              const SizedBox(height: AppSpacing.sm),
              restaurantAsync.when(
                data: (restaurant) => Text(
                  'Questa è una preview rapida di come appare il menu su '
                  'https://${restaurant.slug}.mangialoqui.it/menu.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                loading: () => Text(
                  'Caricamento URL pubblico...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                error: (e, _) => Text(
                  'Errore ristorante: $e',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _PreviewCard(
                categoriesAsync: categoriesAsync,
                itemsAsync: itemsAsync,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _SectionTitle('Stato pubblicazione'),
              const SizedBox(height: AppSpacing.sm),
              versionsAsync.when(
                data: (versions) => _PublishSection(versions: versions),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => Text('Errore versioni: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await ref.read(supabaseClientProvider).auth.signOut();

      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentRestaurantProvider);
      ref.invalidate(currentMenuProvider);
      ref.invalidate(currentThemeProvider);

      if (!mounted) return;
      context.go('/login');
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(letterSpacing: -0.3),
    );
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

class _PreviewCard extends StatelessWidget {
  final AsyncValue categoriesAsync;
  final AsyncValue itemsAsync;

  const _PreviewCard({required this.categoriesAsync, required this.itemsAsync});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _CardContainer(
      child: categoriesAsync.when(
        data: (categories) {
          return itemsAsync.when(
            data: (items) {
              if (categories.isEmpty || items.isEmpty) {
                return Text(
                  'Il menu è vuoto. Aggiungi piatti per vedere la preview.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final category in categories) ...[
                    Text(
                      category.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Divider(color: AppColors.divider),
                    ...items
                        .where((item) => item.categoryId == category.id)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (item.description != null &&
                                          item.description!
                                              .trim()
                                              .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            item.description!,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ),
                                      if (item.isSoldOut)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            'Sold out',
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  color: AppColors.accentDark,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  item.formattedPrice,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Errore piatti: $e'),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Errore categorie: $e'),
      ),
    );
  }
}

class _PublishSection extends ConsumerStatefulWidget {
  final List<MenuVersion> versions;

  const _PublishSection({required this.versions});

  @override
  ConsumerState<_PublishSection> createState() => _PublishSectionState();
}

class _PublishSectionState extends ConsumerState<_PublishSection> {
  bool _publishing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPublished = widget.versions.any((v) => v.isPublished);

    MenuVersion? currentPublished;
    if (hasPublished) {
      currentPublished = widget.versions.firstWhere((v) => v.isPublished);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasPublished)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.accentDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nessuna versione è pubblicata al momento.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.accentDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (currentPublished != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Versione attualmente online',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'v${currentPublished.versionNumber}'
                  '${currentPublished.label != null ? ' – ${currentPublished.label}' : ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _publishing ? null : _publishNewVersion,
                icon: _publishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _publishing
                      ? 'Pubblicazione...'
                      : 'Pubblica versione corrente',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle('Cronologia versioni'),
        const SizedBox(height: AppSpacing.sm),
        if (widget.versions.isEmpty)
          Text(
            'Ancora nessuna versione salvata.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        if (widget.versions.isNotEmpty)
          Column(
            children: widget.versions.map((v) {
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'v${v.versionNumber}'
                            '${v.label != null ? ' – ${v.label}' : ''}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            v.createdAt.toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    v.isPublished
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Online',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.primary,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed: _publishing
                                ? null
                                : () => _restoreVersion(v),
                            child: const Text('Ripristina'),
                          ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _publishNewVersion() async {
    setState(() => _publishing = true);

    try {
      final tuple = await ref.read(menuAndRestaurantProvider.future);
      final restaurant = tuple.first;
      final menu = tuple.second;
      final repository = ref.read(menuPublishRepositoryProvider);

      final createdVersion = await repository.createDraftVersion(
        restaurant: restaurant,
        menu: menu,
        label: 'Pubblicazione ${DateTime.now()}',
      );

      await repository.publishVersion(menu: menu, versionId: createdVersion.id);

      ref.invalidate(menuVersionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Menu pubblicato')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  Future<void> _restoreVersion(MenuVersion version) async {
    setState(() => _publishing = true);

    try {
      final menu = await ref.read(currentMenuProvider.future);

      await ref
          .read(menuPublishRepositoryProvider)
          .publishVersion(menu: menu, versionId: version.id);

      ref.invalidate(menuVersionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Versione ripristinata')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }
}
