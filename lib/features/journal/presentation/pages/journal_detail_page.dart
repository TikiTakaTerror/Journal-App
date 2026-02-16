import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/presentation/pages/journal_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JournalEntryDetailResult {
  const JournalEntryDetailResult({this.updated = false, this.deletedEntry});

  final bool updated;
  final JournalEntry? deletedEntry;
}

class JournalDetailPage extends ConsumerStatefulWidget {
  const JournalDetailPage({super.key, required this.entryId});

  final String entryId;

  static const Key editButtonKey = ValueKey<String>('detail_edit_button');
  static const Key deleteButtonKey = ValueKey<String>('detail_delete_button');

  @override
  ConsumerState<JournalDetailPage> createState() => _JournalDetailPageState();
}

class _JournalDetailPageState extends ConsumerState<JournalDetailPage> {
  bool _wasUpdated = false;

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(journalEntryProvider(widget.entryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry Details'),
        actions: [
          IconButton(
            key: JournalDetailPage.editButtonKey,
            tooltip: 'Edit entry',
            onPressed: () => _editCurrentEntry(entryAsync.value),
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            key: JournalDetailPage.deleteButtonKey,
            tooltip: 'Delete entry',
            onPressed: () => _deleteCurrentEntry(entryAsync.value),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: entryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Unable to load this entry.')),
        data: (entry) {
          if (entry == null) {
            return const Center(child: Text('Entry not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(entry.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  _formatDate(entry.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: SelectableText(
                    entry.content,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.tags
                        .map((tag) => Chip(label: Text(tag)))
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editCurrentEntry(JournalEntry? entry) async {
    if (entry == null) {
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => JournalEditorPage(initialEntry: entry),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    _wasUpdated = true;
    ref.invalidate(journalEntryProvider(widget.entryId));
    ref.invalidate(journalEntriesProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry updated')));
  }

  Future<void> _deleteCurrentEntry(JournalEntry? entry) async {
    if (entry == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete this entry?'),
          content: const Text('You can undo from the previous screen.'),
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

    if (confirm != true || !mounted) {
      return;
    }

    await ref.read(journalRepositoryProvider).deleteEntry(entry.id);
    ref.invalidate(journalEntriesProvider);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(
      JournalEntryDetailResult(deletedEntry: entry, updated: _wasUpdated),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
