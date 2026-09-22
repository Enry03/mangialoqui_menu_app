import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/money_service.dart';
import '../menu_categories/menu_category.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_items/menu_item.dart';
import '../menu_items/menu_items_provider.dart';
import 'ai_provider.dart';
import 'ai_repository.dart';

class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key});

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SpeechToText _speechToText = SpeechToText();
  final FocusNode _inputFocusNode = FocusNode();

  final List<_ChatMessage> _messages = [];

  String _speechTextBefore = '';
  String _speechTextAfter = '';

  bool _speechEnabled = false;
  bool _sending = false;
  bool _botWinking = false;
  late final AnimationController _botThinkingController;
  late final Animation<double> _botThinkingAnimation;

  int? _editingReviewIndex;
  TextEditingController? _reviewEditController;
  bool _confirmingReview = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleComposerChanged);
    _inputFocusNode.addListener(_handleFocusChange);
    _botThinkingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _botThinkingAnimation = CurvedAnimation(
      parent: _botThinkingController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _toggleListening() async {
    if (_speechToText.isListening) {
      await _stopListening();
      return;
    }

    if (!_speechEnabled) {
      try {
        final speechEnabled = await _speechToText.initialize();

        if (!mounted) return;

        setState(() {
          _speechEnabled = speechEnabled;
        });

        if (!speechEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Per usare la dettatura devi consentire l’accesso al microfono.',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossibile avviare il riconoscimento vocale.'),
          ),
        );
        return;
      }
    }

    await _startListening();
  }

  void _handleFocusChange() {
    if (_inputFocusNode.hasFocus) {
      _ensureComposerVisible();
    }
  }

  void _handleComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleComposerChanged);
    _controller.dispose();
    _scrollController.dispose();
    _botThinkingController.dispose();
    _reviewEditController?.dispose();
    _inputFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          toolbarHeight: 88,
          titleSpacing: 18,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
          ),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.72),
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Assistente del menù',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.backgroundTint, AppColors.background],
            ),
          ),
          child: SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 0),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 980;

                    if (isWide) {
                      return _buildChatPanel(isMobile: false);
                    }

                    return _buildMobileLayout();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return _buildChatPanel(isMobile: true);
  }

  Widget _buildComposerInput({
    required bool isMobile,
    required TextStyle composerTextStyle,
    required String? composerGhostText,
  }) {
    final maxLines = isMobile ? 5 : 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        var reservedLines = 1;

        if (composerGhostText != null) {
          final availableTextWidth = constraints.maxWidth > 28
              ? constraints.maxWidth - 28
              : constraints.maxWidth;

          final textPainter = TextPainter(
            text: TextSpan(
              text: '${_controller.text}$composerGhostText',
              style: composerTextStyle,
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: maxLines,
          )..layout(maxWidth: availableTextWidth);

          reservedLines = textPainter
              .computeLineMetrics()
              .length
              .clamp(1, maxLines)
              .toInt();
        }

        return Stack(
          children: [
            TextField(
              controller: _controller,
              focusNode: _inputFocusNode,
              minLines: composerGhostText != null ? reservedLines : 1,
              maxLines: maxLines,
              textAlignVertical: TextAlignVertical.top,
              style: composerTextStyle,
              textInputAction: TextInputAction.newline,
              onTap: () => _scrollToBottom(extraOffset: 220),
              decoration: const InputDecoration(
                hintText: 'Scrivi una modifica del menu...',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            if (composerGhostText != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: RichText(
                          maxLines: maxLines,
                          overflow: TextOverflow.clip,
                          textScaler: MediaQuery.textScalerOf(context),
                          text: TextSpan(
                            style: composerTextStyle,
                            children: [
                              TextSpan(
                                text: _controller.text,
                                style: composerTextStyle.copyWith(
                                  color: Colors.transparent,
                                ),
                              ),
                              TextSpan(
                                text: composerGhostText,
                                style: composerTextStyle.copyWith(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.62,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _isWordCharacter(String value) {
    return RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ0-9]').hasMatch(value);
  }

  TextSpan _buildAssistantMessageSpan(String text) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    var searchFrom = 0;

    while (searchFrom < text.length) {
      final openingQuote = text.indexOf("'", searchFrom);

      if (openingQuote < 0) {
        break;
      }

      final openingInsideWord =
          openingQuote > 0 && _isWordCharacter(text[openingQuote - 1]);

      if (openingInsideWord) {
        searchFrom = openingQuote + 1;
        continue;
      }

      final closingQuote = text.indexOf("'", openingQuote + 1);

      if (closingQuote < 0) {
        break;
      }

      final closingInsideWord =
          closingQuote + 1 < text.length &&
          _isWordCharacter(text[closingQuote + 1]);

      final highlightedText = text
          .substring(openingQuote + 1, closingQuote)
          .trim();

      if (closingInsideWord ||
          highlightedText.isEmpty ||
          highlightedText.contains('\n')) {
        searchFrom = openingQuote + 1;
        continue;
      }

      if (openingQuote > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, openingQuote)));
      }

      spans.add(
        TextSpan(
          text: highlightedText,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

      cursor = closingQuote + 1;
      searchFrom = cursor;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return TextSpan(children: spans);
  }

  Future<void> _playBotWink() async {
    if (_sending || _botWinking) return;

    setState(() {
      _botWinking = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 260));

    if (!mounted) return;

    setState(() {
      _botWinking = false;
    });
  }

  Widget _buildMangiAiBot() {
    final assetPath = _sending
        ? 'assets/branding/mq_bot_thinking.png'
        : _botWinking
        ? 'assets/branding/mq_bot_wink.png'
        : 'assets/branding/mq_bot.png';

    final visualScale = _sending || _botWinking ? 0.87 : 1.0;

    return SizedBox(
      width: 64,
      height: 64,
      child: AnimatedBuilder(
        animation: _botThinkingAnimation,
        builder: (context, child) {
          final progress = _sending ? _botThinkingAnimation.value : 0.0;
          final dy = -2.0 * progress;
          final pulse = 1.0 + (0.025 * progress);

          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(scale: pulse, child: child),
          );
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: Transform.scale(
            key: ValueKey<String>('scale-$assetPath'),
            scale: visualScale,
            child: Image.asset(
              assetPath,
              key: ValueKey<String>(assetPath),
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatPanel({required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                MouseRegion(
                  cursor: _sending
                      ? MouseCursor.defer
                      : SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _sending ? null : _playBotWink,
                    child: _buildMangiAiBot(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chatta con MangiAI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: _messages.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];

                      if (message.isPendingReview) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            constraints: BoxConstraints(
                              maxWidth: isMobile ? 320 : 640,
                            ),
                            child: _buildPendingReviewCard(index, message),
                          ),
                        );
                      }

                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? 320 : 640,
                          ),
                          decoration: BoxDecoration(
                            gradient: message.isUser
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: AppColors.heroGradient,
                                  )
                                : null,
                            color: message.isUser ? null : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: message.isUser
                              ? SelectableText(
                                  message.text,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                  ),
                                )
                              : SelectableText.rich(
                                  _buildAssistantMessageSpan(message.text),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
          if (_sending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'MangiAI sta pensando...',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
              ),
            ),
          _buildComposer(isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildComposer({required bool isMobile}) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final activeCategories =
        ref.watch(menuCategoriesProvider).asData?.value ??
        const <MenuCategory>[];
    final activeItems =
        ref.watch(menuItemsProvider).asData?.value ?? const <MenuItemModel>[];
    final allCategories =
        ref.watch(allMenuCategoriesProvider).asData?.value ?? activeCategories;
    final allItems =
        ref.watch(allMenuItemsProvider).asData?.value ?? activeItems;
    final suggestionGroup = _buildComposerSuggestionGroup(
      activeCategories: activeCategories,
      activeItems: activeItems,
      allCategories: allCategories,
      allItems: allItems,
    );
    final composerGhostText = _buildComposerGhostText(activeCategories);
    final composerTextStyle =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);

    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          isMobile ? (bottomInset > 0 ? 12 : 16) : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildComposerSuggestionArea(suggestionGroup),
            LayoutBuilder(
              builder: (context, constraints) {
                final useStackedLayout = constraints.maxWidth < 430;

                final composerInput = _buildComposerInput(
                  isMobile: isMobile,
                  composerTextStyle: composerTextStyle,
                  composerGhostText: composerGhostText,
                );

                final microphoneButton = IconButton.filledTonal(
                  onPressed: _sending ? null : _toggleListening,
                  icon: Icon(
                    _speechToText.isListening ? Icons.mic : Icons.mic_none,
                  ),
                );

                final sendButton = IconButton.filled(
                  onPressed: _sending ? null : _sendMessage,
                  icon: const Icon(Icons.send),
                );

                if (useStackedLayout) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      composerInput,
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          microphoneButton,
                          const SizedBox(width: 8),
                          sendButton,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: composerInput),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        microphoneButton,
                        const SizedBox(height: 8),
                        sendButton,
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _buildComposerGhostText(List<MenuCategory> activeCategories) {
    final match = RegExp(
      r'^\s*aggiungi\s+un\s+piatto\s+nella\s+categoria\s+(.+?)\s*:\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(_controller.text);

    if (match == null) {
      return null;
    }

    final typedCategoryName = match.group(1)?.trim() ?? '';
    final dishName = match.group(2)?.trim() ?? '';

    if (dishName.isNotEmpty) {
      return null;
    }

    final categoryExists = activeCategories.any(
      (category) =>
          _normalizeComposerText(category.name) ==
          _normalizeComposerText(typedCategoryName),
    );

    if (!categoryExists) {
      return null;
    }

    final separator = RegExp(r'\s$').hasMatch(_controller.text) ? '' : ' ';

    return '$separator Scrivi qui il nome del piatto';
  }

  Widget _buildComposerSuggestionArea(
    _ComposerSuggestionGroup? suggestionGroup,
  ) {
    final hasSuggestions =
        suggestionGroup != null && suggestionGroup.suggestions.isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: !hasSuggestions
            ? const SizedBox.shrink(key: ValueKey('composer-suggestions-empty'))
            : Padding(
                key: ValueKey(suggestionGroup.key),
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestionGroup.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < suggestionGroup.suggestions.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(width: 8),
                            ActionChip(
                              avatar:
                                  suggestionGroup.suggestions[index].icon ==
                                      null
                                  ? null
                                  : Icon(
                                      suggestionGroup.suggestions[index].icon,
                                      size: 18,
                                    ),
                              label: Text(
                                suggestionGroup.suggestions[index].label,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _applyComposerText(
                                suggestionGroup.suggestions[index].textToApply,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  _ComposerSuggestionGroup? _buildComposerSuggestionGroup({
    required List<MenuCategory> activeCategories,
    required List<MenuItemModel> activeItems,
    required List<MenuCategory> allCategories,
    required List<MenuItemModel> allItems,
  }) {
    final text = _controller.text;
    final normalizedText = _normalizeComposerText(text);

    if (normalizedText.isEmpty) {
      return const _ComposerSuggestionGroup(
        key: 'initial',
        label: 'Cosa vuoi fare?',
        suggestions: [
          _ComposerSuggestion(
            label: 'Aggiungi',
            icon: Icons.add_rounded,
            textToApply: 'Aggiungi ',
          ),
          _ComposerSuggestion(
            label: 'Nascondi',
            icon: Icons.visibility_off_outlined,
            textToApply: 'Nascondi ',
          ),
          _ComposerSuggestion(
            label: 'Riattiva',
            icon: Icons.visibility_outlined,
            textToApply: 'Riattiva ',
          ),
        ],
      );
    }

    if (normalizedText == 'aggiungi') {
      return const _ComposerSuggestionGroup(
        key: 'add-type',
        label: 'Cosa vuoi aggiungere?',
        suggestions: [
          _ComposerSuggestion(
            label: 'Piatto',
            icon: Icons.restaurant_menu_rounded,
            textToApply: 'Aggiungi un piatto nella categoria ',
          ),
          _ComposerSuggestion(
            label: 'Categoria',
            icon: Icons.category_outlined,
            textToApply: 'Aggiungi categoria ',
          ),
        ],
      );
    }

    final addItemWithCategoryMatch = RegExp(
      r'^\s*aggiungi\s+un\s+piatto\s+nella\s+categoria\s+(.+?)\s*:\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (addItemWithCategoryMatch != null) {
      final typedCategoryName = addItemWithCategoryMatch.group(1)?.trim() ?? '';
      final dishName = addItemWithCategoryMatch.group(2)?.trim() ?? '';
      MenuCategory? selectedCategory;

      for (final category in activeCategories) {
        if (_normalizeComposerText(category.name) ==
            _normalizeComposerText(typedCategoryName)) {
          selectedCategory = category;
          break;
        }
      }

      if (selectedCategory == null ||
          dishName.isEmpty ||
          _containsComposerPrice(dishName)) {
        return null;
      }

      final naturalPrefix =
          'Aggiungi $dishName nella categoria ${selectedCategory.name} a ';

      return _ComposerSuggestionGroup(
        key: 'add-price',
        label: 'Completa il prezzo',
        suggestions: [
          for (final price in const [5, 8, 10, 12])
            _ComposerSuggestion(
              label: '$price €',
              icon: Icons.euro_rounded,
              textToApply: '$naturalPrefix$price €',
            ),
          _ComposerSuggestion(
            label: 'Altro prezzo',
            icon: Icons.edit_outlined,
            textToApply: naturalPrefix,
          ),
        ],
      );
    }

    final addItemCategoryMatch = RegExp(
      r'^\s*aggiungi\s+un\s+piatto\s+nella\s+categoria\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (addItemCategoryMatch != null) {
      final query = _normalizeComposerText(addItemCategoryMatch.group(1) ?? '');
      final categories = activeCategories
          .where((category) => _matchesComposerQuery(category.name, query))
          .take(20)
          .toList();

      return _ComposerSuggestionGroup(
        key: 'add-category-choice',
        label: 'Scegli una categoria',
        suggestions: [
          for (final category in categories)
            _ComposerSuggestion(
              label: category.name,
              icon: Icons.category_outlined,
              textToApply:
                  'Aggiungi un piatto nella categoria ${category.name}: ',
            ),
          const _ComposerSuggestion(
            label: 'Crea prima una categoria',
            icon: Icons.create_new_folder_outlined,
            textToApply: 'Aggiungi categoria ',
          ),
        ],
      );
    }

    if (normalizedText == 'nascondi') {
      return const _ComposerSuggestionGroup(
        key: 'hide-type',
        label: 'Cosa vuoi nascondere?',
        suggestions: [
          _ComposerSuggestion(
            label: 'Piatto',
            icon: Icons.restaurant_menu_rounded,
            textToApply: 'Nascondi piatto ',
          ),
          _ComposerSuggestion(
            label: 'Categoria',
            icon: Icons.category_outlined,
            textToApply: 'Nascondi categoria ',
          ),
        ],
      );
    }

    final hideCategoryMatch = RegExp(
      r'^\s*nascondi\s+(?:la\s+)?categoria\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (hideCategoryMatch != null) {
      final query = _normalizeComposerText(hideCategoryMatch.group(1) ?? '');
      final suggestions = activeCategories
          .where((category) => _matchesComposerQuery(category.name, query))
          .where(
            (category) =>
                normalizedText !=
                _normalizeComposerText(
                  'Nascondi la categoria ${category.name}',
                ),
          )
          .take(20)
          .map(
            (category) => _ComposerSuggestion(
              label: category.name,
              icon: Icons.visibility_off_outlined,
              textToApply: 'Nascondi la categoria ${category.name}',
            ),
          )
          .toList();

      return _suggestionGroupOrNull(
        key: 'hide-category',
        label: 'Scegli una categoria',
        suggestions: suggestions,
      );
    }

    final activeCategoryById = {
      for (final category in activeCategories) category.id: category,
    };
    final hideItemMatch = RegExp(
      r'^\s*nascondi\s+(?:il\s+)?piatto\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (hideItemMatch != null) {
      final query = _normalizeComposerText(hideItemMatch.group(1) ?? '');
      final suggestions = <_ComposerSuggestion>[];

      for (final item in activeItems) {
        final category = activeCategoryById[item.categoryId];

        if (category == null ||
            !_matchesComposerQuery('${item.name} ${category.name}', query)) {
          continue;
        }

        suggestions.add(
          _ComposerSuggestion(
            label: '${item.name} · ${category.name}',
            icon: Icons.visibility_off_outlined,
            textToApply:
                'Nascondi il piatto ${item.name} della categoria ${category.name}',
          ),
        );

        if (suggestions.length >= 20) {
          break;
        }
      }

      return _suggestionGroupOrNull(
        key: 'hide-item',
        label: 'Scegli un piatto',
        suggestions: suggestions,
      );
    }

    if (normalizedText == 'riattiva') {
      return const _ComposerSuggestionGroup(
        key: 'reactivate-type',
        label: 'Cosa vuoi riattivare?',
        suggestions: [
          _ComposerSuggestion(
            label: 'Piatto',
            icon: Icons.restaurant_menu_rounded,
            textToApply: 'Riattiva piatto ',
          ),
          _ComposerSuggestion(
            label: 'Categoria',
            icon: Icons.category_outlined,
            textToApply: 'Riattiva categoria ',
          ),
        ],
      );
    }

    final reactivateCategoryMatch = RegExp(
      r'^\s*riattiva\s+(?:la\s+)?categoria\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (reactivateCategoryMatch != null) {
      final query = _normalizeComposerText(
        reactivateCategoryMatch.group(1) ?? '',
      );
      final suggestions = allCategories
          .where((category) => !category.menuCategoryActive)
          .where((category) => _matchesComposerQuery(category.name, query))
          .where(
            (category) =>
                normalizedText !=
                _normalizeComposerText(
                  'Riattiva la categoria ${category.name}',
                ),
          )
          .take(20)
          .map(
            (category) => _ComposerSuggestion(
              label: category.name,
              icon: Icons.visibility_outlined,
              textToApply: 'Riattiva la categoria ${category.name}',
            ),
          )
          .toList();

      return _suggestionGroupOrNull(
        key: 'reactivate-category',
        label: 'Scegli una categoria',
        suggestions: suggestions,
      );
    }

    final allCategoryById = {
      for (final category in allCategories) category.id: category,
    };
    final reactivateItemMatch = RegExp(
      r'^\s*riattiva\s+(?:il\s+)?piatto\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (reactivateItemMatch != null) {
      final query = _normalizeComposerText(reactivateItemMatch.group(1) ?? '');
      final suggestions = <_ComposerSuggestion>[];

      for (final item in allItems) {
        final category = allCategoryById[item.categoryId];
        final canReactivateItem =
            category != null &&
            category.menuCategoryActive &&
            !item.menuItemActive;

        if (!canReactivateItem ||
            !_matchesComposerQuery('${item.name} ${category.name}', query)) {
          continue;
        }

        suggestions.add(
          _ComposerSuggestion(
            label: '${item.name} · ${category.name}',
            icon: Icons.visibility_outlined,
            textToApply:
                'Riattiva il piatto ${item.name} della categoria ${category.name}',
          ),
        );

        if (suggestions.length >= 20) {
          break;
        }
      }

      return _suggestionGroupOrNull(
        key: 'reactivate-item',
        label: 'Scegli un piatto',
        suggestions: suggestions,
      );
    }

    return null;
  }

  _ComposerSuggestionGroup? _suggestionGroupOrNull({
    required String key,
    required String label,
    required List<_ComposerSuggestion> suggestions,
  }) {
    if (suggestions.isEmpty) {
      return null;
    }

    return _ComposerSuggestionGroup(
      key: key,
      label: label,
      suggestions: suggestions,
    );
  }

  bool _matchesComposerQuery(String value, String normalizedQuery) {
    return normalizedQuery.isEmpty ||
        _normalizeComposerText(value).contains(normalizedQuery);
  }

  bool _containsComposerPrice(String value) {
    return RegExp(
      r'\d+(?:[.,]\d{1,2})?\s*(?:€|euro)',
      caseSensitive: false,
    ).hasMatch(value);
  }

  String _normalizeComposerText(String value) {
    var normalized = value.toLowerCase();
    const replacements = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
    };

    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }

    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _applyComposerText(String text) {
    if (!mounted) {
      return;
    }

    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _inputFocusNode.requestFocus();
    _ensureComposerVisible();
  }

  void _ensureComposerVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      if (position.maxScrollExtent - position.pixels > 24) {
        _scrollToBottom(extraOffset: 180);
      }
    });
  }

  Future<int> _getNextCategorySortOrder(String menuId) async {
    final rows = await _client
        .from('menu_categories')
        .select('sort_order')
        .eq('menu_id', menuId);

    int next = 0;
    for (final row in (rows as List)) {
      final value = row['sort_order'];
      if (value is int && value >= next) {
        next = value + 1;
      }
    }
    return next;
  }

  Future<int> _getNextItemSortOrder({
    required String menuId,
    required String categoryId,
  }) async {
    final rows = await _client
        .from('menu_items')
        .select('sort_order')
        .eq('menu_id', menuId)
        .eq('category_id', categoryId);

    int next = 0;
    for (final row in (rows as List)) {
      final value = row['sort_order'];
      if (value is int && value >= next) {
        next = value + 1;
      }
    }
    return next;
  }

  Future<Map<String, dynamic>> _buildMenuSnapshot(String menuId) async {
    final categoriesResponse = await _client
        .from('menu_categories')
        .select()
        .eq('menu_id', menuId)
        .order('sort_order', ascending: true);

    final itemsResponse = await _client
        .from('menu_items')
        .select()
        .eq('menu_id', menuId)
        .order('sort_order', ascending: true);

    final categories = (categoriesResponse as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final items = (itemsResponse as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return {'categories': categories, 'items': items};
  }

  Future<void> _refreshMenuState() async {
    ref.invalidate(menuCategoriesProvider);
    ref.invalidate(allMenuCategoriesProvider);
    ref.invalidate(menuItemsProvider);
    ref.invalidate(allMenuItemsProvider);
    ref.invalidate(currentMenuProvider);
  }

  Future<bool> _hideCategoryByName({
    required String menuId,
    required String categoryName,
    required List<String> debugLines,
  }) async {
    final categories = await _client
        .from('menu_categories')
        .select('id,name')
        .eq('menu_id', menuId)
        .ilike('name', categoryName);

    if ((categories as List).isEmpty) {
      debugLines.add('hide_category: categoria non trovata: $categoryName');
      return false;
    }

    final category = categories.first;
    final categoryId = category['id'] as String;

    await _client
        .from('menu_categories')
        .update({'menu_category_active': false})
        .eq('menu_id', menuId)
        .eq('id', categoryId);

    debugLines.add(
      'hide_category ok: $categoryName; stato dei piatti invariato',
    );
    return true;
  }

  Future<bool> _reactivateCategoryByName({
    required String menuId,
    required String categoryName,
    required List<String> debugLines,
  }) async {
    final categories = await _client
        .from('menu_categories')
        .select('id,name')
        .eq('menu_id', menuId)
        .ilike('name', categoryName);

    if ((categories as List).isEmpty) {
      debugLines.add(
        'reactivate_category: categoria non trovata: $categoryName',
      );
      return false;
    }

    final category = categories.first;
    final categoryId = category['id'] as String;

    await _client
        .from('menu_categories')
        .update({'menu_category_active': true})
        .eq('menu_id', menuId)
        .eq('id', categoryId);

    debugLines.add(
      'reactivate_category ok: $categoryName; stato dei piatti invariato',
    );
    return true;
  }

  Future<bool> _hideItemByName({
    required String menuId,
    required String itemName,
    required String? categoryName,
    required List<String> debugLines,
  }) async {
    String? categoryId;

    if (categoryName != null && categoryName.trim().isNotEmpty) {
      final categories = await _client
          .from('menu_categories')
          .select('id')
          .eq('menu_id', menuId)
          .ilike('name', categoryName.trim());

      if ((categories as List).isNotEmpty) {
        categoryId = categories.first['id'] as String;
      }
    }

    var query = _client
        .from('menu_items')
        .select('id,name')
        .eq('menu_id', menuId)
        .ilike('name', itemName);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final items = await query;

    if ((items as List).isEmpty) {
      debugLines.add('hide_item: piatto non trovato: $itemName');
      return false;
    }

    for (final raw in items) {
      final item = raw;
      await _client
          .from('menu_items')
          .update({'menu_item_active': false})
          .eq('menu_id', menuId)
          .eq('id', item['id'] as String);
    }

    debugLines.add('hide_item ok: $itemName');
    return true;
  }

  Future<_ReactivateItemResult> _reactivateItemByName({
    required String menuId,
    required String itemName,
    required String? categoryName,
    required List<String> debugLines,
  }) async {
    String? requestedCategoryId;

    if (categoryName != null && categoryName.trim().isNotEmpty) {
      final categories = await _client
          .from('menu_categories')
          .select('id')
          .eq('menu_id', menuId)
          .ilike('name', categoryName.trim());

      if ((categories as List).isNotEmpty) {
        requestedCategoryId = categories.first['id'] as String;
      }
    }

    var query = _client
        .from('menu_items')
        .select('id,name,category_id')
        .eq('menu_id', menuId)
        .ilike('name', itemName);

    if (requestedCategoryId != null) {
      query = query.eq('category_id', requestedCategoryId);
    }

    final items = await query;

    if ((items as List).isEmpty) {
      debugLines.add('reactivate_item: piatto non trovato: $itemName');
      return const _ReactivateItemResult(applied: false);
    }

    final categoryIds = <String>{};

    for (final raw in items) {
      final categoryId = raw['category_id'] as String?;

      if (categoryId != null && categoryId.isNotEmpty) {
        categoryIds.add(categoryId);
      }
    }

    for (final categoryId in categoryIds) {
      final categories = await _client
          .from('menu_categories')
          .select('id,name,menu_category_active')
          .eq('menu_id', menuId)
          .eq('id', categoryId)
          .limit(1);

      if ((categories as List).isEmpty) {
        continue;
      }

      final category = categories.first;
      final categoryActive = category['menu_category_active'] as bool? ?? true;

      if (!categoryActive) {
        final parentCategoryName =
            category['name'] as String? ?? categoryName ?? 'categoria';

        debugLines.add(
          'reactivate_item bloccata: categoria disattivata: $parentCategoryName',
        );

        return _ReactivateItemResult(
          applied: false,
          replyOverride:
              'Prima di riattivare il piatto "$itemName", devi riattivare la categoria "$parentCategoryName".',
        );
      }
    }

    for (final raw in items) {
      await _client
          .from('menu_items')
          .update({'menu_item_active': true})
          .eq('menu_id', menuId)
          .eq('id', raw['id'] as String);
    }

    debugLines.add('reactivate_item ok: $itemName');

    return const _ReactivateItemResult(applied: true);
  }

  List<Map<String, String>> _buildConversationContext() {
    const maxMessages = 8;
    const maxCharactersPerMessage = 1000;
    const maxTotalCharacters = 6000;

    final recentMessages = _messages.length <= maxMessages
        ? List<_ChatMessage>.from(_messages)
        : _messages.sublist(_messages.length - maxMessages);

    final context = <Map<String, String>>[];
    var remainingCharacters = maxTotalCharacters;

    for (final message in recentMessages.reversed) {
      if (remainingCharacters <= 0) {
        break;
      }

      var content = message.text.trim();

      if (content.isEmpty) {
        continue;
      }

      if (content.length > maxCharactersPerMessage) {
        content = content.substring(0, maxCharactersPerMessage);
      }

      if (content.length > remainingCharacters) {
        content = content.substring(0, remainingCharacters);
      }

      context.insert(0, {
        'role': message.isUser ? 'user' : 'assistant',
        'content': content,
      });

      remainingCharacters -= content.length;
    }

    return context;
  }

  Future<void> _sendMessage() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    final conversationContext = _buildConversationContext();

    FocusScope.of(context).unfocus();

    _botThinkingController.repeat(reverse: true);

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(text: prompt, isUser: true));
      _controller.clear();
    });

    _scrollToBottom(extraOffset: 200);

    try {
      final restaurant = await ref.read(currentRestaurantProvider.future);
      final menu = await ref.read(currentMenuProvider.future);
      final aiRepo = ref.read(aiRepositoryProvider);

      final snapshotBefore = await _buildMenuSnapshot(menu.id);

      final aiResult = await aiRepo.askAi(
        restaurantId: restaurant.id,
        menuId: menu.id,
        prompt: prompt,
        menuSnapshot: snapshotBefore,
        conversationContext: conversationContext,
      );

      debugPrint(
        '[AI DEBUG] messaggi contesto: ${conversationContext.length}; '
        'actions ricevute: ${aiResult.actions.length}; '
        'payload raw: ${jsonEncode(aiResult.rawData)}',
      );

      // Più di 2 modifiche in un solo messaggio: non applicarle subito,
      // mostra prima un riepilogo da confermare (o correggere) a mano.
      const maxActionsBeforeReview = 2;

      if (aiResult.actions.length > maxActionsBeforeReview) {
        final warningsText = aiResult.warnings.isEmpty
            ? ''
            : '\n\n❓ Da controllare tu (non ho capito bene o non ho aggiunto):\n'
                  '${aiResult.warnings.map((w) => '• $w').join('\n')}';

        final draftText = _buildDraftTextFromActions(aiResult.actions);

        setState(() {
          _messages.add(
            _ChatMessage(text: '${aiResult.reply}$warningsText', isUser: false),
          );

          if (draftText.isNotEmpty) {
            _messages.add(
              _ChatMessage(
                text: '',
                isUser: false,
                isPendingReview: true,
                draftText: draftText,
                draftActions: aiResult.actions,
              ),
            );
          }
        });

        _scrollToBottom(extraOffset: 220);
        return;
      }

      final debugLines = <String>[
        'restaurantId: ${restaurant.id}',
        'menuId: ${menu.id}',
        'messaggi contesto: ${conversationContext.length}',
        'actions ricevute: ${aiResult.actions.length}',
        'payload raw: ${jsonEncode(aiResult.rawData)}',
      ];

      final applyResult = await _applyAiActions(
        menuId: menu.id,
        actions: aiResult.actions,
        debugLines: debugLines,
      );

      final replyOverride = applyResult.replyOverride;
      final finalReply = replyOverride ?? aiResult.reply;

      await aiRepo.saveHistory(
        restaurantId: restaurant.id,
        menuId: menu.id,
        prompt: prompt,
        aiResponse: finalReply,
        actionSummary: replyOverride ?? aiResult.summary,
        source: 'chat',
        menuSnapshot: snapshotBefore,
      );

      for (final line in debugLines) {
        debugPrint('[AI DEBUG] $line');
      }

      final detailedReport = _buildDetailedReport(
        result: applyResult,
        warnings: aiResult.warnings,
      );

      final resultMessage = detailedReport.isEmpty
          ? finalReply
          : '$finalReply\n\n$detailedReport';

      setState(() {
        _messages.add(_ChatMessage(text: resultMessage, isUser: false));
      });

      await _refreshMenuState();
      _scrollToBottom(extraOffset: 220);
    } on PostgrestException catch (e) {
      debugPrint(
        '[AI ERROR][POSTGREST] '
        'message=${e.message}; '
        'code=${e.code}; '
        'details=${e.details}; '
        'hint=${e.hint}',
      );

      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'Non sono riuscito ad applicare la modifica al menu.',
            isUser: false,
          ),
        );
      });
      _scrollToBottom(extraOffset: 220);
    } catch (e, stackTrace) {
      debugPrint('[AI ERROR] $e');
      debugPrintStack(stackTrace: stackTrace);

      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'Si è verificato un errore durante la richiesta AI.',
            isUser: false,
          ),
        );
      });
      _scrollToBottom(extraOffset: 220);
    } finally {
      if (mounted) {
        _botThinkingController
          ..stop()
          ..value = 0;
        setState(() {
          _sending = false;
        });
      }
    }
  }

  String _buildDraftTextFromActions(List<AiAction> actions) {
    final buffer = StringBuffer();
    final otherLines = <String>[];
    String? currentCategory;

    for (final action in actions) {
      if (action.type == 'create_category') {
        final name = action.name?.trim() ?? '';
        if (name.isEmpty) continue;

        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(name);
        currentCategory = name;
        continue;
      }

      if (action.type == 'create_item') {
        final name = action.name?.trim() ?? '';
        final categoryName = action.categoryName?.trim() ?? '';
        if (name.isEmpty) continue;

        if (categoryName.isNotEmpty && categoryName != currentCategory) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.writeln(categoryName);
          currentCategory = categoryName;
        }

        final description = action.description?.trim();
        final priceCents = action.priceCents;
        final price = priceCents != null
            ? MoneyService.centsToEuroText(priceCents)
            : 'prezzo mancante';

        final parts = [
          name,
          if (description != null && description.isNotEmpty) description,
          price,
        ];

        buffer.writeln('- ${parts.join(' — ')}');
        continue;
      }

      final name = action.name?.trim() ?? '';
      if (name.isEmpty) continue;

      switch (action.type) {
        case 'hide_category':
          otherLines.add('🙈 Nascondi la categoria "$name"');
        case 'reactivate_category':
          otherLines.add('♻️ Riattiva la categoria "$name"');
        case 'hide_item':
          otherLines.add('🙈 Nascondi il piatto "$name"');
        case 'reactivate_item':
          otherLines.add('♻️ Riattiva il piatto "$name"');
      }
    }

    if (otherLines.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('Altre modifiche');
      for (final line in otherLines) {
        buffer.writeln(line);
      }
    }

    return buffer.toString().trim();
  }

  Widget _buildPendingReviewCard(int index, _ChatMessage message) {
    final theme = Theme.of(context);
    final isEditing = _editingReviewIndex == index;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.playlist_add_check_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ho aggiunto:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isEditing)
            TextField(
              controller: _reviewEditController,
              maxLines: null,
              minLines: 4,
              style: const TextStyle(color: AppColors.textPrimary),
            )
          else
            SelectableText(
              message.draftText ?? '',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: isEditing
                ? [
                    TextButton(
                      onPressed: _confirmingReview
                          ? null
                          : () => _cancelEditingReview(),
                      child: const Text('Annulla modifica'),
                    ),
                    FilledButton(
                      onPressed: _confirmingReview
                          ? null
                          : () => _saveEditingReview(index),
                      child: const Text('Salva modifiche'),
                    ),
                  ]
                : [
                    OutlinedButton.icon(
                      onPressed: _confirmingReview
                          ? null
                          : () => _startEditingReview(index, message),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Modifica'),
                    ),
                    FilledButton.icon(
                      onPressed: _confirmingReview
                          ? null
                          : () => _confirmPendingReview(index),
                      icon: _confirmingReview
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Conferma'),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  void _startEditingReview(int index, _ChatMessage message) {
    setState(() {
      _editingReviewIndex = index;
      _reviewEditController = TextEditingController(
        text: message.draftText ?? '',
      );
    });
  }

  void _cancelEditingReview() {
    setState(() {
      _editingReviewIndex = null;
      _reviewEditController = null;
    });
  }

  void _saveEditingReview(int index) {
    final editedText = _reviewEditController?.text.trim() ?? '';
    final current = _messages[index];

    setState(() {
      _messages[index] = _ChatMessage(
        text: current.text,
        isUser: current.isUser,
        isPendingReview: current.isPendingReview,
        draftText: editedText,
        // Testo modificato a mano: le azioni originali non sono più valide,
        // alla conferma va richiesto di nuovo all'AI di interpretarlo.
        draftActions: null,
      );
      _editingReviewIndex = null;
      _reviewEditController = null;
    });
  }

  Future<void> _confirmPendingReview(int index) async {
    if (_confirmingReview) return;

    final message = _messages[index];
    final draftText = message.draftText?.trim() ?? '';

    if (draftText.isEmpty) return;

    setState(() {
      _confirmingReview = true;
    });

    try {
      final restaurant = await ref.read(currentRestaurantProvider.future);
      final menu = await ref.read(currentMenuProvider.future);
      final aiRepo = ref.read(aiRepositoryProvider);

      final snapshotBefore = await _buildMenuSnapshot(menu.id);

      List<AiAction> actionsToApply;
      String reply;
      String summary;
      List<String> warnings;
      Map<String, dynamic> rawDataForDebug;

      if (message.draftActions != null) {
        // Testo non modificato: applica esattamente le azioni che l'AI
        // aveva già proposto, senza un'altra chiamata (più veloce e
        // coerente con quanto mostrato nel riepilogo).
        actionsToApply = message.draftActions!;
        reply = 'Modifiche confermate.';
        summary = reply;
        warnings = const [];
        rawDataForDebug = {'source': 'draftActions', 'count': actionsToApply.length};
      } else {
        final aiResult = await aiRepo.askAi(
          restaurantId: restaurant.id,
          menuId: menu.id,
          prompt: 'Applica queste modifiche al menu:\n\n$draftText',
          menuSnapshot: snapshotBefore,
          conversationContext: const [],
        );

        actionsToApply = aiResult.actions;
        reply = aiResult.reply;
        summary = aiResult.summary;
        warnings = aiResult.warnings;
        rawDataForDebug = aiResult.rawData;
      }

      final debugLines = <String>[
        'restaurantId: ${restaurant.id}',
        'menuId: ${menu.id}',
        'conferma riepilogo; actions ricevute: ${actionsToApply.length}',
        'payload raw: ${jsonEncode(rawDataForDebug)}',
      ];

      final applyResult = await _applyAiActions(
        menuId: menu.id,
        actions: actionsToApply,
        debugLines: debugLines,
      );

      final finalReply = applyResult.replyOverride ?? reply;

      await aiRepo.saveHistory(
        restaurantId: restaurant.id,
        menuId: menu.id,
        prompt: 'Conferma riepilogo modifiche menu',
        aiResponse: finalReply,
        actionSummary: applyResult.replyOverride ?? summary,
        source: 'chat_review_confirmed',
        menuSnapshot: snapshotBefore,
      );

      for (final line in debugLines) {
        debugPrint('[AI DEBUG] $line');
      }

      final detailedReport = _buildDetailedReport(
        result: applyResult,
        warnings: warnings,
      );

      final resultMessage = detailedReport.isEmpty
          ? finalReply
          : '$finalReply\n\n$detailedReport';

      if (!mounted) return;

      setState(() {
        _messages[index] = _ChatMessage(text: resultMessage, isUser: false);
      });

      await _refreshMenuState();
      _scrollToBottom(extraOffset: 220);
    } on PostgrestException catch (e) {
      debugPrint(
        '[AI ERROR][POSTGREST] '
        'message=${e.message}; '
        'code=${e.code}; '
        'details=${e.details}; '
        'hint=${e.hint}',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non sono riuscito ad applicare le modifiche.'),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('[AI ERROR] $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Si è verificato un errore durante la conferma.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _confirmingReview = false;
        });
      }
    }
  }

  Future<_ApplyActionsResult> _applyAiActions({
    required String menuId,
    required List<AiAction> actions,
    required List<String> debugLines,
  }) async {
    int appliedActions = 0;
    String? replyOverride;
    final addedCategories = <String>[];
    final addedItems = <String>[];
    final duplicateCategories = <String>[];
    final duplicateItems = <String>[];
    final hiddenLabels = <String>[];
    final reactivatedLabels = <String>[];
    final notFoundLabels = <String>[];

    for (final action in actions) {
      debugLines.add('azione: ${action.type} -> ${jsonEncode(action.raw)}');

      if (action.type == 'create_category') {
        final name = action.name?.trim();
        if (name == null || name.isEmpty) {
          debugLines.add('create_category saltata: name vuoto');
          continue;
        }

        final existing = await _client
            .from('menu_categories')
            .select('id')
            .eq('menu_id', menuId)
            .ilike('name', name);

        if ((existing as List).isNotEmpty) {
          debugLines.add('categoria già esistente: $name');
          duplicateCategories.add(name);
          continue;
        }

        final nextSortOrder = await _getNextCategorySortOrder(menuId);

        final inserted = await _client.from('menu_categories').insert({
          'menu_id': menuId,
          'name': name,
          'sort_order': nextSortOrder,
        }).select();

        debugLines.add('insert categoria ok: ${jsonEncode(inserted)}');
        addedCategories.add(name);
        appliedActions++;
        continue;
      }

      if (action.type == 'delete_category' || action.type == 'hide_category') {
        final name = action.name?.trim();
        if (name == null || name.isEmpty) {
          debugLines.add('hide_category saltata: name vuoto');
          continue;
        }

        final found = await _hideCategoryByName(
          menuId: menuId,
          categoryName: name,
          debugLines: debugLines,
        );

        if (found) {
          hiddenLabels.add('Categoria "$name"');
          appliedActions++;
        } else {
          notFoundLabels.add('Categoria "$name"');
        }
        continue;
      }

      if (action.type == 'reactivate_category') {
        final name = action.name?.trim();
        if (name == null || name.isEmpty) {
          debugLines.add('reactivate_category saltata: name vuoto');
          continue;
        }

        final found = await _reactivateCategoryByName(
          menuId: menuId,
          categoryName: name,
          debugLines: debugLines,
        );

        if (found) {
          reactivatedLabels.add('Categoria "$name"');
          appliedActions++;
        } else {
          notFoundLabels.add('Categoria "$name"');
        }
        continue;
      }

      if (action.type == 'create_item') {
        final name = action.name?.trim();
        final categoryName = action.categoryName?.trim();
        final priceCents = action.priceCents;
        final currency = (action.currency ?? 'EUR').trim();

        if (name == null || name.isEmpty) {
          debugLines.add('create_item saltata: name vuoto');
          continue;
        }
        if (categoryName == null || categoryName.isEmpty) {
          debugLines.add('create_item saltata: categoryName vuoto');
          continue;
        }
        if (priceCents == null || priceCents <= 0) {
          debugLines.add(
            'create_item saltata: priceCents nullo o non valido',
          );
          continue;
        }

        final categories = await _client
            .from('menu_categories')
            .select('id,name')
            .eq('menu_id', menuId)
            .ilike('name', categoryName);

        String? categoryId;

        if ((categories as List).isNotEmpty) {
          categoryId = categories.first['id'] as String;
        } else {
          final nextCategorySortOrder = await _getNextCategorySortOrder(
            menuId,
          );

          final createdCategory = await _client
              .from('menu_categories')
              .insert({
                'menu_id': menuId,
                'name': categoryName,
                'sort_order': nextCategorySortOrder,
              })
              .select()
              .single();

          categoryId = createdCategory['id'] as String;
          debugLines.add(
            'categoria auto-creata: ${jsonEncode(createdCategory)}',
          );
          addedCategories.add(categoryName);
        }

        final existingItems = await _client
            .from('menu_items')
            .select('id')
            .eq('menu_id', menuId)
            .eq('category_id', categoryId)
            .ilike('name', name);

        if ((existingItems as List).isNotEmpty) {
          debugLines.add('piatto già esistente: $name');
          duplicateItems.add('$name ($categoryName)');
          continue;
        }

        final nextItemSortOrder = await _getNextItemSortOrder(
          menuId: menuId,
          categoryId: categoryId,
        );

        final insertedItem = await _client.from('menu_items').insert({
          'menu_id': menuId,
          'category_id': categoryId,
          'name': name,
          'description': action.description,
          'price_cents': priceCents,
          'currency': currency,
          'sort_order': nextItemSortOrder,
          'is_sold_out': false,
        }).select();

        debugLines.add('insert piatto ok: ${jsonEncode(insertedItem)}');
        addedItems.add('$name ($categoryName)');
        appliedActions++;
        continue;
      }

      if (action.type == 'delete_item' || action.type == 'hide_item') {
        final name = action.name?.trim();
        if (name == null || name.isEmpty) {
          debugLines.add('hide_item saltata: name vuoto');
          continue;
        }

        final found = await _hideItemByName(
          menuId: menuId,
          itemName: name,
          categoryName: action.categoryName,
          debugLines: debugLines,
        );

        if (found) {
          hiddenLabels.add('Piatto "$name"');
          appliedActions++;
        } else {
          notFoundLabels.add('Piatto "$name"');
        }
        continue;
      }

      if (action.type == 'reactivate_item') {
        final name = action.name?.trim();
        if (name == null || name.isEmpty) {
          debugLines.add('reactivate_item saltata: name vuoto');
          continue;
        }

        final result = await _reactivateItemByName(
          menuId: menuId,
          itemName: name,
          categoryName: action.categoryName,
          debugLines: debugLines,
        );

        if (result.replyOverride != null) {
          replyOverride = result.replyOverride;
        }

        if (!result.applied && result.replyOverride == null) {
          notFoundLabels.add('Piatto "$name"');
        }

        if (result.applied) {
          reactivatedLabels.add('Piatto "$name"');
          appliedActions++;
        }
        continue;
      }

      debugLines.add('azione non gestita: ${action.type}');
    }

    return _ApplyActionsResult(
      appliedActions: appliedActions,
      replyOverride: replyOverride,
      addedCategories: addedCategories,
      addedItems: addedItems,
      duplicateCategories: duplicateCategories,
      duplicateItems: duplicateItems,
      hiddenLabels: hiddenLabels,
      reactivatedLabels: reactivatedLabels,
      notFoundLabels: notFoundLabels,
    );
  }

  String _buildDetailedReport({
    required _ApplyActionsResult result,
    required List<String> warnings,
  }) {
    final sections = <String>[];

    final addedParts = <String>[
      if (result.addedCategories.isNotEmpty)
        '${result.addedCategories.length} categorie: ${result.addedCategories.join(', ')}',
      if (result.addedItems.isNotEmpty)
        '${result.addedItems.length} piatti: ${result.addedItems.join(', ')}',
    ];
    if (addedParts.isNotEmpty) {
      sections.add('✅ Aggiunto:\n${addedParts.map((p) => '• $p').join('\n')}');
    }

    if (result.reactivatedLabels.isNotEmpty) {
      sections.add(
        '♻️ Riattivato: ${result.reactivatedLabels.join(', ')}.',
      );
    }

    if (result.hiddenLabels.isNotEmpty) {
      sections.add('🙈 Nascosto: ${result.hiddenLabels.join(', ')}.');
    }

    final duplicateParts = <String>[
      if (result.duplicateCategories.isNotEmpty)
        'categorie già presenti: ${result.duplicateCategories.join(', ')}',
      if (result.duplicateItems.isNotEmpty)
        'piatti già presenti: ${result.duplicateItems.join(', ')}',
    ];
    if (duplicateParts.isNotEmpty) {
      sections.add(
        '↩️ Non aggiunto (già esistente): ${duplicateParts.join(' — ')}.',
      );
    }

    if (result.notFoundLabels.isNotEmpty) {
      sections.add(
        '⚠️ Non trovato nel menu attuale: ${result.notFoundLabels.join(', ')}.',
      );
    }

    if (warnings.isNotEmpty) {
      sections.add(
        '❓ Da controllare tu (non ho capito bene o non ho aggiunto):\n'
        '${warnings.map((w) => '• $w').join('\n')}',
      );
    }

    return sections.join('\n\n');
  }

  Future<void> _startListening() async {
    final currentText = _controller.text;
    final selection = _controller.selection;

    final selectionStart = selection.isValid
        ? selection.start.clamp(0, currentText.length).toInt()
        : currentText.length;
    final selectionEnd = selection.isValid
        ? selection.end.clamp(0, currentText.length).toInt()
        : currentText.length;

    _speechTextBefore = currentText.substring(0, selectionStart);
    _speechTextAfter = currentText.substring(selectionEnd);

    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final spokenText = result.recognizedWords.trim();

    final needsLeadingSpace =
        spokenText.isNotEmpty &&
        _speechTextBefore.isNotEmpty &&
        !RegExp(r'\s$').hasMatch(_speechTextBefore);

    final needsTrailingSpace =
        spokenText.isNotEmpty &&
        _speechTextAfter.isNotEmpty &&
        !RegExp(r'^\s').hasMatch(_speechTextAfter);

    final leadingSpace = needsLeadingSpace ? ' ' : '';
    final trailingSpace = needsTrailingSpace ? ' ' : '';

    final dictatedText = '$leadingSpace$spokenText$trailingSpace';

    final updatedText =
        '$_speechTextBefore$dictatedText$_speechTextAfter';

    final cursorOffset =
        _speechTextBefore.length + leadingSpace.length + spokenText.length;

    setState(() {
      _controller.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: cursorOffset),
      );
    });

    _scrollToBottom(extraOffset: 220);
  }

  void _scrollToBottom({double extraOffset = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = _scrollController.position.maxScrollExtent + extraOffset;
        _scrollController.animateTo(
          target.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _ReactivateItemResult {
  final bool applied;
  final String? replyOverride;

  const _ReactivateItemResult({required this.applied, this.replyOverride});
}

class _ApplyActionsResult {
  final int appliedActions;
  final String? replyOverride;
  final List<String> addedCategories;
  final List<String> addedItems;
  final List<String> duplicateCategories;
  final List<String> duplicateItems;
  final List<String> hiddenLabels;
  final List<String> reactivatedLabels;
  final List<String> notFoundLabels;

  const _ApplyActionsResult({
    required this.appliedActions,
    this.replyOverride,
    this.addedCategories = const [],
    this.addedItems = const [],
    this.duplicateCategories = const [],
    this.duplicateItems = const [],
    this.hiddenLabels = const [],
    this.reactivatedLabels = const [],
    this.notFoundLabels = const [],
  });
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isPendingReview;
  final String? draftText;
  // Azioni già ottenute dall'AI per questo riepilogo. Se il ristoratore
  // modifica il testo a mano, questo campo viene azzerato: alla conferma
  // andrà rimandato all'AI, perché il testo non corrisponde più a queste
  // azioni. Se resta invariato, la conferma le applica direttamente senza
  // un'altra chiamata AI.
  final List<AiAction>? draftActions;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isPendingReview = false,
    this.draftText,
    this.draftActions,
  });
}

class _ComposerSuggestion {
  final String label;
  final IconData? icon;
  final String textToApply;

  const _ComposerSuggestion({
    required this.label,
    this.icon,
    required this.textToApply,
  });
}

class _ComposerSuggestionGroup {
  final String key;
  final String label;
  final List<_ComposerSuggestion> suggestions;

  const _ComposerSuggestionGroup({
    required this.key,
    required this.label,
    required this.suggestions,
  });
}
