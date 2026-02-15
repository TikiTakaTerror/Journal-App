import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JournalEditorPage extends ConsumerStatefulWidget {
  const JournalEditorPage({super.key});

  static const Key titleFieldKey = ValueKey<String>('journal_title_field');
  static const Key contentFieldKey = ValueKey<String>('journal_content_field');
  static const Key tagsFieldKey = ValueKey<String>('journal_tags_field');
  static const Key saveButtonKey = ValueKey<String>('journal_save_button');
  static const Key recentEntriesListKey = ValueKey<String>(
    'journal_recent_entries_list',
  );

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
                flex: 2,
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
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Recent Entries',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Expanded(child: _RecentEntriesList()),
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
      ref.invalidate(journalEntriesProvider);
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

class _RecentEntriesList extends ConsumerWidget {
  const _RecentEntriesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsyncValue = ref.watch(journalEntriesProvider);

    return entriesAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Unable to load entries right now.')),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(child: Text('No journal entries yet.'));
        }

        return ListView.separated(
          key: JournalEditorPage.recentEntriesListKey,
          itemCount: entries.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _JournalEntryListTile(entry: entry);
          },
        );
      },
    );
  }
}

class _JournalEntryListTile extends StatelessWidget {
  const _JournalEntryListTile({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        entry.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatDate(entry.updatedAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
