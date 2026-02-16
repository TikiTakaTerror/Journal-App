import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
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

  @override
  ConsumerState<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends ConsumerState<JournalEditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

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
    final isCompact = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(editorState.isEditing ? 'Edit Entry' : 'New Entry'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Close'),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (editorState.isSaving) const LinearProgressIndicator(),
                  _EditorGuideCard(
                    isEditing: editorState.isEditing,
                    words: words,
                    characters: characters,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: JournalEditorPage.titleFieldKey,
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Name this entry',
                    ),
                    onChanged: ref
                        .read(journalEditorControllerProvider.notifier)
                        .updateTitle,
                  ),
                  const SizedBox(height: 12),
                  _FormattingToolbar(
                    compact: isCompact,
                    onBold: () => _wrapSelection('**', '**'),
                    onItalic: () => _wrapSelection('_', '_'),
                    onHeading: () => _insertAtSelection('\n## '),
                    onBullet: () => _insertAtSelection('\n- '),
                    onQuote: () => _insertAtSelection('\n> '),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      key: JournalEditorPage.contentFieldKey,
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        labelText: 'Write',
                        hintText: 'Capture your thoughts with clarity...',
                      ),
                      onChanged: ref
                          .read(journalEditorControllerProvider.notifier)
                          .updateContent,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: JournalEditorPage.saveButtonKey,
                    onPressed: editorState.canSave ? _save : null,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      editorState.isEditing ? 'Update Entry' : 'Save Entry',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    final saved = await ref
        .read(journalEditorControllerProvider.notifier)
        .save();
    if (!mounted) {
      return;
    }

    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }

    final message = ref.read(journalEditorControllerProvider).errorMessage;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
    final buttons = [
      OutlinedButton(
        key: JournalEditorPage.boldButtonKey,
        onPressed: onBold,
        child: const Text('Bold'),
      ),
      OutlinedButton(
        key: JournalEditorPage.italicButtonKey,
        onPressed: onItalic,
        child: const Text('Italic'),
      ),
      OutlinedButton(
        key: JournalEditorPage.headingButtonKey,
        onPressed: onHeading,
        child: const Text('H2'),
      ),
      OutlinedButton(
        key: JournalEditorPage.bulletButtonKey,
        onPressed: onBullet,
        child: const Text('Bullet'),
      ),
      OutlinedButton(
        key: JournalEditorPage.quoteButtonKey,
        onPressed: onQuote,
        child: const Text('Quote'),
      ),
    ];

    if (compact) {
      final compactChildren = <Widget>[];
      for (var i = 0; i < buttons.length; i++) {
        compactChildren.add(buttons[i]);
        if (i != buttons.length - 1) {
          compactChildren.add(const SizedBox(width: 8));
        }
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: compactChildren),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

class _EditorGuideCard extends StatelessWidget {
  const _EditorGuideCard({
    required this.isEditing,
    required this.words,
    required this.characters,
  });

  final bool isEditing;
  final int words;
  final int characters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_note : Icons.auto_stories,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEditing
                  ? 'Refine your reflection with specific details and outcomes.'
                  : 'Start with one concrete moment, then add what you felt and learned.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$words words',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                '$characters chars',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
