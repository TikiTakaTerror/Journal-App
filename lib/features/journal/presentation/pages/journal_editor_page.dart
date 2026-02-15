import 'dart:async';

import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/presentation/state/journal_editor_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JournalEditorPage extends ConsumerStatefulWidget {
  const JournalEditorPage({super.key});

  static const Key titleFieldKey = ValueKey<String>('journal_title_field');
  static const Key contentFieldKey = ValueKey<String>('journal_content_field');
  static const Key tagsFieldKey = ValueKey<String>('journal_tags_field');
  static const Key saveButtonKey = ValueKey<String>('journal_save_button');
  static const Key clearEditorButtonKey = ValueKey<String>(
    'journal_clear_editor_button',
  );
  static const Key themeToggleButtonKey = ValueKey<String>(
    'journal_theme_toggle_button',
  );
  static const Key searchFieldKey = ValueKey<String>('journal_search_field');
  static const Key tagFilterFieldKey = ValueKey<String>(
    'journal_tag_filter_field',
  );
  static const Key clearFiltersButtonKey = ValueKey<String>(
    'journal_clear_filters_button',
  );
  static const Key recentEntriesListKey = ValueKey<String>(
    'journal_recent_entries_list',
  );
  static const Key mobileLayoutScrollKey = ValueKey<String>(
    'journal_mobile_layout_scroll',
  );

  @override
  ConsumerState<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends ConsumerState<JournalEditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _searchController = TextEditingController();
  final _tagFilterController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _searchController.dispose();
    _tagFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(journalEditorControllerProvider);
    final themeMode = ref.watch(themeModeProvider);

    final editorPane = _EditorPane(
      titleController: _titleController,
      contentController: _contentController,
      tagsController: _tagsController,
      editorState: editorState,
      onSave: _saveEntry,
      onClear: _clearEditor,
      onTitleChanged: ref
          .read(journalEditorControllerProvider.notifier)
          .updateTitle,
      onContentChanged: ref
          .read(journalEditorControllerProvider.notifier)
          .updateContent,
      onTagsChanged: ref
          .read(journalEditorControllerProvider.notifier)
          .updateTagsInput,
    );

    final entriesPane = _EntriesPane(
      searchController: _searchController,
      tagFilterController: _tagFilterController,
      onSearchChanged: (value) {
        ref.read(journalSearchQueryProvider.notifier).state = value;
      },
      onTagFilterChanged: (value) {
        ref.read(journalTagFilterProvider.notifier).state = value;
      },
      onClearFilters: _clearFilters,
      onSelectEntry: _loadEntryForEditing,
      onDeleteEntry: _confirmAndDeleteEntry,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Journal'),
        actions: [
          IconButton(
            key: JournalEditorPage.themeToggleButtonKey,
            tooltip: 'Toggle theme',
            onPressed: () => _toggleTheme(themeMode),
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1000) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(flex: 6, child: editorPane),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: entriesPane),
                  ],
                ),
              );
            }

            final paneHeight = constraints.maxHeight < 900 ? 340.0 : 420.0;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                key: JournalEditorPage.mobileLayoutScrollKey,
                children: [
                  SizedBox(height: paneHeight, child: editorPane),
                  const SizedBox(height: 16),
                  SizedBox(height: paneHeight, child: entriesPane),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _toggleTheme(ThemeMode currentMode) {
    ref.read(themeModeProvider.notifier).state = currentMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  Future<void> _saveEntry() async {
    final currentState = ref.read(journalEditorControllerProvider);
    final wasEditing = currentState.isEditing;
    final editingId = currentState.editingEntryId;

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
      if (editingId != null && editingId.isNotEmpty) {
        ref.read(selectedEntryIdProvider.notifier).state = editingId;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wasEditing ? 'Entry updated' : 'Entry saved')),
      );
      return;
    }

    final message = ref.read(journalEditorControllerProvider).errorMessage;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _clearEditor() {
    ref.read(journalEditorControllerProvider.notifier).clearEditor();
    _titleController.clear();
    _contentController.clear();
    _tagsController.clear();
  }

  void _clearFilters() {
    _searchController.clear();
    _tagFilterController.clear();
    ref.read(journalSearchQueryProvider.notifier).state = '';
    ref.read(journalTagFilterProvider.notifier).state = '';
  }

  void _loadEntryForEditing(JournalEntry entry) {
    ref.read(journalEditorControllerProvider.notifier).loadForEditing(entry);
    ref.read(selectedEntryIdProvider.notifier).state = entry.id;
    _titleController.text = entry.title;
    _contentController.text = entry.content;
    _tagsController.text = entry.tags.join(', ');
  }

  Future<void> _confirmAndDeleteEntry(JournalEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this entry?'),
          content: const Text(
            'This action cannot be undone unless restored now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    await ref.read(journalRepositoryProvider).deleteEntry(entry.id);
    if (!mounted) {
      return;
    }

    if (ref.read(journalEditorControllerProvider).editingEntryId == entry.id) {
      _clearEditor();
    }

    if (ref.read(selectedEntryIdProvider) == entry.id) {
      ref.read(selectedEntryIdProvider.notifier).state = null;
    }

    ref.invalidate(journalEntriesProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            unawaited(_restoreDeletedEntry(entry));
          },
        ),
      ),
    );
  }

  Future<void> _restoreDeletedEntry(JournalEntry entry) async {
    await ref.read(journalRepositoryProvider).upsertEntry(entry);
    if (!mounted) {
      return;
    }

    ref.read(selectedEntryIdProvider.notifier).state = entry.id;
    ref.invalidate(journalEntriesProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry restored')));
  }
}

class _EditorPane extends StatelessWidget {
  const _EditorPane({
    required this.titleController,
    required this.contentController,
    required this.tagsController,
    required this.editorState,
    required this.onSave,
    required this.onClear,
    required this.onTitleChanged,
    required this.onContentChanged,
    required this.onTagsChanged,
  });

  final TextEditingController titleController;
  final TextEditingController contentController;
  final TextEditingController tagsController;
  final JournalEditorState editorState;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onContentChanged;
  final ValueChanged<String> onTagsChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: JournalEditorPage.titleFieldKey,
              controller: titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'What is on your mind?',
              ),
              onChanged: onTitleChanged,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                key: JournalEditorPage.contentFieldKey,
                controller: contentController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'Entry',
                  hintText: 'Write freely...',
                ),
                onChanged: onContentChanged,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: JournalEditorPage.tagsFieldKey,
              controller: tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'wellness, gratitude',
              ),
              onChanged: onTagsChanged,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: JournalEditorPage.saveButtonKey,
                    onPressed: editorState.canSave ? onSave : null,
                    child: editorState.isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            editorState.isEditing
                                ? 'Update Entry'
                                : 'Save Entry',
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: JournalEditorPage.clearEditorButtonKey,
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntriesPane extends ConsumerWidget {
  const _EntriesPane({
    required this.searchController,
    required this.tagFilterController,
    required this.onSearchChanged,
    required this.onTagFilterChanged,
    required this.onClearFilters,
    required this.onSelectEntry,
    required this.onDeleteEntry,
  });

  final TextEditingController searchController;
  final TextEditingController tagFilterController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTagFilterChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<JournalEntry> onSelectEntry;
  final ValueChanged<JournalEntry> onDeleteEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedEntryAsync = ref.watch(selectedEntryProvider);
    final entriesAsyncValue = ref.watch(journalEntriesProvider);
    final entriesSection = entriesAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('Unable to load entries right now.'),
      data: (entries) {
        if (entries.isEmpty) {
          return const Text('No journal entries yet.');
        }

        return Column(
          key: JournalEditorPage.recentEntriesListKey,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              _JournalEntryListTile(
                entry: entries[i],
                onTap: () => onSelectEntry(entries[i]),
                onDelete: () => onDeleteEntry(entries[i]),
              ),
              if (i < entries.length - 1) const Divider(height: 1),
            ],
          ],
        );
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: JournalEditorPage.searchFieldKey,
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  hintText: 'Search title or content',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: onSearchChanged,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: JournalEditorPage.tagFilterFieldKey,
                      controller: tagFilterController,
                      decoration: const InputDecoration(
                        labelText: 'Tag Filter',
                        hintText: 'Filter by tag',
                        prefixIcon: Icon(Icons.tag),
                      ),
                      onChanged: onTagFilterChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: JournalEditorPage.clearFiltersButtonKey,
                    onPressed: onClearFilters,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              selectedEntryAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (entry) {
                  if (entry == null) {
                    return const SizedBox.shrink();
                  }

                  return _EntryDetailsCard(entry: entry);
                },
              ),
              if (selectedEntryAsync.asData?.value != null)
                const SizedBox(height: 12),
              Text(
                'Recent Entries',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              entriesSection,
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryDetailsCard extends StatelessWidget {
  const _EntryDetailsCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Entry Details', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(entry.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(entry.content),
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.tags
                  .map((tag) => Chip(label: Text(tag)))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _JournalEntryListTile extends StatelessWidget {
  const _JournalEntryListTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        entry.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDate(entry.updatedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          IconButton(
            key: ValueKey<String>('delete_entry_${entry.id}'),
            tooltip: 'Delete entry',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
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
