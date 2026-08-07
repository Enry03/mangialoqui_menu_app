//* Toast (banner veloce) stile Prenow.
//* Sostituisce gli SnackBar standard con un messaggio elegante
//* in ALTO sotto AppBar, con comparsa/scomparsa rapidissima.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum AppToastKind { info, success, warning, error }

class AppToast {
  AppToast._();

  static OverlayEntry? _activeEntry;

  /// Info (blu Menu Pro)
  static void info(BuildContext context, String message, {bool flash = false}) {
    _show(context, message, kind: AppToastKind.info, flash: flash);
  }

  /// Successo (verde soft)
  static void success(
    BuildContext context,
    String message, {
    bool flash = false,
  }) {
    _show(context, message, kind: AppToastKind.success, flash: flash);
  }

  /// Avviso (ambra)
  static void warning(
    BuildContext context,
    String message, {
    bool flash = false,
  }) {
    _show(context, message, kind: AppToastKind.warning, flash: flash);
  }

  /// Errore (rosso)
  static void error(
    BuildContext context,
    String message, {
    bool flash = false,
  }) {
    _show(context, message, kind: AppToastKind.error, flash: flash);
  }

  static void _show(
    BuildContext context,
    String message, {
    required AppToastKind kind,
    required bool flash,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    // Evita crash se il caller arriva da un async e la pagina è stata chiusa.
    if (context is Element && !context.mounted) return;

    // Uno alla volta: se ne arriva uno nuovo, il precedente sparisce subito.
    _activeEntry?.remove();
    _activeEntry = null;

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;

    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        final safeTop = MediaQuery.of(overlayContext).padding.top;
        final appBarHeight = Scaffold.maybeOf(context)?.appBarMaxHeight ?? 0.0;
        final topOffset = safeTop + appBarHeight + 8.0;

        return _PrenoToastHost(
          message: trimmed,
          kind: kind,
          flash: flash,
          topOffset: topOffset,
          onClose: () {
            final e = entry;
            if (e == null) return;
            if (_activeEntry == e) _activeEntry = null;
            e.remove();
          },
        );
      },
    );

    _activeEntry = entry;
    overlayState.insert(entry);
  }
}

class _PrenoToastHost extends StatefulWidget {
  final String message;
  final AppToastKind kind;
  final bool flash;
  final double topOffset;
  final VoidCallback onClose;

  const _PrenoToastHost({
    required this.message,
    required this.kind,
    required this.flash,
    required this.topOffset,
    required this.onClose,
  });

  @override
  State<_PrenoToastHost> createState() => _PrenoToastHostState();
}

class _PrenoToastHostState extends State<_PrenoToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();

    // Rapidissimo: comparsa/scomparsa tipo "blink elegante".
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 120),
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(curve);

    _controller.forward();

    final visible = _visibleDuration(widget.kind, widget.flash);
    _hideTimer = Timer(visible, _hide);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  static Duration _visibleDuration(AppToastKind kind, bool flash) {
    if (flash) return const Duration(milliseconds: 900);

    switch (kind) {
      case AppToastKind.info:
      case AppToastKind.success:
        return const Duration(milliseconds: 1600);
      case AppToastKind.warning:
        return const Duration(milliseconds: 2200);
      case AppToastKind.error:
        return const Duration(milliseconds: 3200);
    }
  }

  Future<void> _hide() async {
    if (!mounted) return;

    try {
      await _controller.reverse();
    } finally {
      if (mounted) widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(widget.kind);

    // Non deve bloccare tap/drag nell'app.
    return IgnorePointer(
      ignoring: true,
      child: Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(
              top: widget.topOffset,
              left: 12,
              right: 12,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: style.accent.withValues(alpha: 0.22),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(width: 4, height: 52, color: style.accent),
                          const SizedBox(width: 10),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: style.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              style.icon,
                              size: 20,
                              color: style.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                widget.message,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black.withValues(
                                        alpha: 0.86,
                                      ),
                                      height: 1.2,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ToastStyle _styleFor(AppToastKind kind) {
    switch (kind) {
      case AppToastKind.info:
        return const _ToastStyle(
          accent: AppColors.primary,
          icon: Icons.info_outline_rounded,
        );
      case AppToastKind.success:
        return const _ToastStyle(
          accent: Color(0xFF16A34A),
          icon: Icons.check_circle_outline_rounded,
        );
      case AppToastKind.warning:
        return const _ToastStyle(
          accent: Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
        );
      case AppToastKind.error:
        return const _ToastStyle(
          accent: Color(0xFFDC2626),
          icon: Icons.error_outline_rounded,
        );
    }
  }
}

class _ToastStyle {
  final Color accent;
  final IconData icon;

  const _ToastStyle({required this.accent, required this.icon});
}
