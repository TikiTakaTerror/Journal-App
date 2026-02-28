import 'dart:async';

import 'package:ai_journal/app/design_system/components/app_surface_card.dart';
import 'package:ai_journal/app/design_system/components/collapsible_section.dart';
import 'package:ai_journal/app/design_system/components/editor_toolbar_button.dart';
import 'package:ai_journal/app/design_system/components/inline_notice.dart';
import 'package:ai_journal/app/design_system/components/pill_chip.dart';
import 'package:ai_journal/app/design_system/components/primary_action_button.dart';
import 'package:ai_journal/app/design_system/components/section_header.dart';
import 'package:ai_journal/app/design_system/tokens/spacing.dart';
import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/ai/presentation/widgets/ai_companion_sheet.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JournalEditorPage extends ConsumerStatefulWidget {
  const JournalEditorPage({super.key, this.initialEntry});

  final JournalEntry? initialEntry;

  static const Key titleFieldKey = ValueKey<String>('journal_title_field');
  static const Key contentFieldKey = ValueKey<String>('journal_content_field');
  static const Key tagsFieldKey = ValueKey<String>('journal_tags_field');
  static const Key saveButtonKey = ValueKey<String>('journal_save_button');
  static const Key boldButtonKey = ValueKey<String>('format_bold_button');
  static const Key italicButtonKey = ValueKey<String>('format_italic_button');
  static const Key headingButtonKey = ValueKey<String>('format_heading_button');
  static const Key bulletButtonKey = ValueKey<String>('format_bullet_button');
  static const Key quoteButtonKey = ValueKey<String>('format_quote_button');
  static const Key reflectionDialogKey = ValueKey<String>(
    'journal_reflection_dialog',
  );
  static const Key reflectionContinueButtonKey = ValueKey<String>(
    'journal_reflection_continue_button',
  );
  static const Key reflectionRetryButtonKey = ValueKey<String>(
    'journal_reflection_retry_button',
  );
  static const Key companionButtonKey = ValueKey<String>(
    'journal_companion_button',
  );

  @override
  ConsumerState<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends ConsumerState<JournalEditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _savedInSession = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    if (entry != null) {
      _titleController.text = entry.title;
      _contentController.text = entry.content;
      _tagsController.text = entry.tags.join(', ');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final notifier = ref.read(journalEditorControllerProvider.notifier);
      if (entry == null) {
        notifier.clearEditor();
        return;
      }

      notifier.loadForEditing(entry);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(journalEditorControllerProvider);
    final words = _countWords(editorState.content);
    final characters = editorState.content.trim().length;
    final isCompact = MediaQuery.sizeOf(context).width < 920;

    return Scaffold(
      appBar: AppBar(
        title: Text(editorState.isEditing ? 'Edit Entry' : 'New Entry'),
        actions: [
          IconButton(
            key: JournalEditorPage.companionButtonKey,
            tooltip: 'Open AI companion',
            onPressed: _openCompanionSheet,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          TextButton(
            onPressed: _closeEditor,
            child: Text(_savedInSession ? 'Done' : 'Close'),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: AppSpace.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (editorState.isSaving) const LinearProgressIndicator(),
                  _EditorHeader(
                    isEditing: editorState.isEditing,
                    words: words,
                    characters: characters,
                    onUsePrompt: _applyPromptStarter,
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (editorState.saveSucceeded) ...[
                    const InlineNotice(
                      tone: InlineNoticeTone.success,
                      message:
                          'Saved locally. You can continue editing or tap Done to return.',
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  if (editorState.reflectionStatus != ReflectionStatus.idle ||
                      editorState.hasReflection ||
                      (editorState.reflectionErrorMessage != null &&
                          editorState.reflectionErrorMessage!.isNotEmpty)) ...[
                    _ReflectionSection(
                      state: editorState,
                      onRetry: () {
                        unawaited(
                          ref
                              .read(journalEditorControllerProvider.notifier)
                              .retryReflection(),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                  TextField(
                    key: JournalEditorPage.titleFieldKey,
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    style: Theme.of(context).textTheme.titleLarge,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Name this entry',
                    ),
                    onChanged: ref
                        .read(journalEditorControllerProvider.notifier)
                        .updateTitle,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _FormattingToolbar(
                    compact: isCompact,
                    onBold: () => _wrapSelection('**', '**'),
                    onItalic: () => _wrapSelection('_', '_'),
                    onHeading: () => _insertAtSelection('\n## '),
                    onBullet: () => _insertAtSelection('\n- '),
                    onQuote: () => _insertAtSelection('\n> '),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Expanded(
                    child: AppSurfaceCard(
                      padding: const EdgeInsets.all(0),
                      child: TextField(
                        key: JournalEditorPage.contentFieldKey,
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: const InputDecoration(
                          alignLabelWithHint: true,
                          labelText: 'Write',
                          hintText: 'Capture the moment, what you felt, and what mattered.',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        onChanged: ref
                            .read(journalEditorControllerProvider.notifier)
                            .updateContent,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  if (isCompact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: JournalEditorPage.tagsFieldKey,
                          controller: _tagsController,
                          decoration: const InputDecoration(
                            labelText: 'Tags',
                            hintText: 'wellness, work, gratitude',
                          ),
                          onChanged: ref
                              .read(journalEditorControllerProvider.notifier)
                              .updateTagsInput,
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          'AI suggestions are optional and supportive only.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            key: JournalEditorPage.tagsFieldKey,
                            controller: _tagsController,
                            decoration: const InputDecoration(
                              labelText: 'Tags',
                              hintText: 'wellness, work, gratitude',
                            ),
                            onChanged: ref
                                .read(journalEditorControllerProvider.notifier)
                                .updateTagsInput,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        const Expanded(
                          child: InlineNotice(
                            tone: InlineNoticeTone.info,
                            message:
                                'AI suggestions are optional. Supportive prompts only, not therapy or crisis care.',
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpace.sm),
                  PrimaryActionButton(
                    key: JournalEditorPage.saveButtonKey,
                    onPressed: editorState.saveSucceeded
                        ? _closeEditor
                        : (editorState.canSave ? _save : null),
                    icon: editorState.saveSucceeded
                        ? Icons.check
                        : Icons.save_outlined,
                    label: editorState.saveSucceeded
                        ? 'Done'
                        : (editorState.isEditing ? 'Save Changes' : 'Save Entry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _closeEditor() {
    Navigator.of(context).pop(_savedInSession ? true : null);
  }

  Future<void> _openCompanionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => const AICompanionSheet(),
    );
  }

  void _applyPromptStarter(String starter) {
    if (_contentController.text.trim().isEmpty) {
      _contentController.text = '$starter\n\n';
    } else {
      _contentController.text = '${_contentController.text.trim()}\n\n$starter\n';
    }
    _contentController.selection = TextSelection.collapsed(
      offset: _contentController.text.length,
    );
    _notifyContentChanged();
  }

  void _wrapSelection(String prefix, String suffix) {
    final value = _contentController.value;
    final text = value.text;
    final selection = value.selection;

    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      _contentController.text += '$prefix$suffix';
      _contentController.selection = TextSelection.collapsed(
        offset: _contentController.text.length - suffix.length,
      );
      _notifyContentChanged();
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final selected = text.substring(start, end);
    final replaced = '$prefix$selected$suffix';
    final updated = text.replaceRange(start, end, replaced);

    _contentController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + replaced.length),
    );
    _notifyContentChanged();
  }

  void _insertAtSelection(String insertText) {
    final value = _contentController.value;
    final text = value.text;
    final selection = value.selection;

    if (!selection.isValid || selection.start < 0) {
      _contentController.text += insertText;
      _contentController.selection = TextSelection.collapsed(
        offset: _contentController.text.length,
      );
      _notifyContentChanged();
      return;
    }

    final updated = text.replaceRange(
      selection.start,
      selection.end,
      insertText,
    );
    final cursor = selection.start + insertText.length;

    _contentController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _notifyContentChanged();
  }

  void _notifyContentChanged() {
    ref
        .read(journalEditorControllerProvider.notifier)
        .updateContent(_contentController.text);
  }

  int _countWords(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 0;
    }

    return trimmed.split(RegExp(r'\s+')).length;
  }

  Future<void> _save() async {
    final saved = await ref.read(journalEditorControllerProvider.notifier).save();
    if (!mounted) {
      return;
    }

    if (saved) {
      setState(() {
        _savedInSession = true;
      });
      _showSnackBar(const SnackBar(content: Text('Entry saved locally')));
      return;
    }

    final message = ref.read(journalEditorControllerProvider).errorMessage;
    if (message != null && message.isNotEmpty) {
      _showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showSnackBar(SnackBar snackBar) {
    final messenger = ScaffoldMessenger.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomOffset =
        AppSpace.xl +
        kBottomNavigationBarHeight +
        mediaQuery.padding.bottom +
        mediaQuery.viewInsets.bottom;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: snackBar.content,
          duration: snackBar.duration,
          action: snackBar.action,
          behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(
            AppSpace.lg,
            0,
            AppSpace.lg,
            bottomOffset,
          ),
        ),
      );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.isEditing,
    required this.words,
    required this.characters,
    required this.onUsePrompt,
  });

  final bool isEditing;
  final int words;
  final int characters;
  final ValueChanged<String> onUsePrompt;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: isEditing ? 'Refine your entry' : 'Write without friction',
            subtitle: isEditing
                ? 'Focus on what changed, what you felt, and what you learned.'
                : 'Start with one concrete moment. AI stays in the background.',
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$words words', style: Theme.of(context).textTheme.labelLarge),
                Text(
                  '$characters chars',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                PillChip(
                  label: 'What happened first?',
                  icon: Icons.play_arrow_outlined,
                  onTap: () =>
                      onUsePrompt('What happened first, and what stood out?'),
                ),
                const SizedBox(width: 8),
                PillChip(
                  label: 'What did I feel?',
                  icon: Icons.favorite_border,
                  onTap: () => onUsePrompt(
                    'What emotions did I notice in that moment?',
                  ),
                ),
                const SizedBox(width: 8),
                PillChip(
                  label: 'What next?',
                  icon: Icons.arrow_forward_outlined,
                  onTap: () =>
                      onUsePrompt('What is one next step I want to try?'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionSection extends StatelessWidget {
  const _ReflectionSection({required this.state, required this.onRetry});

  final JournalEditorState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (state.reflectionStatus) {
      case ReflectionStatus.loading:
        body = const InlineNotice(
          tone: InlineNoticeTone.info,
          icon: Icons.auto_awesome,
          message: 'Generating a short reflection... You can keep editing or tap Done anytime.',
        );
      case ReflectionStatus.success:
        body = SelectableText(
          state.reflectionText ?? '',
          style: Theme.of(context).textTheme.bodyMedium,
        );
      case ReflectionStatus.error:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InlineNotice(
              tone: InlineNoticeTone.error,
              message: state.reflectionErrorMessage ??
                  'Unable to generate AI reflection right now.',
            ),
            if (state.canRetryReflection) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: JournalEditorPage.reflectionRetryButtonKey,
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry reflection'),
                ),
              ),
            ],
          ],
        );
      case ReflectionStatus.idle:
        body = const SizedBox.shrink();
    }

    return CollapsibleSection(
      key: JournalEditorPage.reflectionDialogKey,
      title: 'AI Reflection',
      subtitle: 'Optional post-save perspective, kept concise.',
      leading: const Icon(Icons.auto_awesome_outlined, size: 18),
      initiallyExpanded: true,
      trailing: state.reflectionStatus == ReflectionStatus.loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: body,
    );
  }
}

class _FormattingToolbar extends StatelessWidget {
  const _FormattingToolbar({
    required this.compact,
    required this.onBold,
    required this.onItalic,
    required this.onHeading,
    required this.onBullet,
    required this.onQuote,
  });

  final bool compact;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onHeading;
  final VoidCallback onBullet;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      EditorToolbarButton(
        key: JournalEditorPage.boldButtonKey,
        icon: Icons.format_bold,
        tooltip: 'Bold',
        label: 'Bold',
        onPressed: onBold,
      ),
      EditorToolbarButton(
        key: JournalEditorPage.italicButtonKey,
        icon: Icons.format_italic,
        tooltip: 'Italic',
        label: 'Italic',
        onPressed: onItalic,
      ),
      EditorToolbarButton(
        key: JournalEditorPage.headingButtonKey,
        icon: Icons.title,
        tooltip: 'Heading',
        label: 'H2',
        onPressed: onHeading,
      ),
      EditorToolbarButton(
        key: JournalEditorPage.bulletButtonKey,
        icon: Icons.format_list_bulleted,
        tooltip: 'Bullet list',
        label: 'Bullet',
        onPressed: onBullet,
      ),
      EditorToolbarButton(
        key: JournalEditorPage.quoteButtonKey,
        icon: Icons.format_quote,
        tooltip: 'Quote',
        label: 'Quote',
        onPressed: onQuote,
      ),
    ];

    return AppSurfaceCard(
      padding: const EdgeInsets.all(10),
      child: compact
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    buttons[i],
                    if (i != buttons.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            )
          : Wrap(spacing: 8, runSpacing: 8, children: buttons),
    );
  }
}
