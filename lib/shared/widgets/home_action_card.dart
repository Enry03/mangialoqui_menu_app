import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class HomeActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Layout verticale e più denso, pensato per griglie a 2 colonne.
  final bool compact;

  const HomeActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<HomeActionCard> createState() => _HomeActionCardState();
}

class _HomeActionCardState extends State<HomeActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(
                alpha: _pressed ? 0.07 : 0.10,
              ),
              blurRadius: _pressed ? 16 : 26,
              offset: Offset(0, _pressed ? 6 : 12),
            ),
          ],
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                widget.compact ? AppSpacing.lg : AppSpacing.xl,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surface, AppColors.backgroundTint],
                ),
              ),
              child: widget.compact ? _buildCompact() : _buildRegular(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon({required double size}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _pressed
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(widget.icon, color: AppColors.primary),
    );
  }

  Widget _buildCompact() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(size: 44),
        const Spacer(),
        Text(
          widget.title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildRegular(ThemeData theme) {
    return Row(
      children: [
        _buildIcon(size: 56),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: _pressed ? AppColors.white : AppColors.primary,
          ),
        ),
      ],
    );
  }
}
