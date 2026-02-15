import 'package:ai_journal/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JournalEditorPage extends ConsumerStatefulWidget {
  const JournalEditorPage({super.key});

  static const Key titleFieldKey = ValueKey<String>('journal_title_field');
  static const Key contentFieldKey = ValueKey<String>('journal_content_field');
  static const Key tagsFieldKey = ValueKey<String>('journal_tags_field');
  static const Key saveButtonKey = ValueKey<String>('journal_save_button');

  @override
  ConsumerState<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends ConsumerState<JournalEditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

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

    return Scaffold(
      appBar: AppBar(title: const Text('AI Journal')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: JournalEditorPage.titleFieldKey,
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What is on your mind?',
                ),
                onChanged: ref
                    .read(journalEditorControllerProvider.notifier)
                    .updateTitle,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  key: JournalEditorPage.contentFieldKey,
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    labelText: 'Entry',
                    hintText: 'Write freely...',
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
                  hintText: 'wellness, gratitude',
                ),
                onChanged: ref
                    .read(journalEditorControllerProvider.notifier)
                    .updateTagsInput,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: JournalEditorPage.saveButtonKey,
                onPressed: editorState.canSave ? _saveEntry : null,
                child: editorState.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveEntry() async {
    final saved = await ref
        .read(journalEditorControllerProvider.notifier)
        .save();
    if (!mounted) {
      return;
    }

    if (saved) {
      _titleController.clear();
      _contentController.clear();
      _tagsController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entry saved')));
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
