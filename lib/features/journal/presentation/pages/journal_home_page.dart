import 'dart:async';

import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/journal/presentation/pages/journal_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JournalHomePage extends ConsumerStatefulWidget {
  const JournalHomePage({super.key});

  static const Key searchFieldKey = ValueKey<String>('home_search_field');
  static const Key tagFieldKey = ValueKey<String>('home_tag_field');
  static const Key entriesListKey = ValueKey<String>('home_entries_list');
  static const Key generatePromptButtonKey = ValueKey<String>(
    'home_generate_prompt_button',
  );
  static const Key promptTextKey = ValueKey<String>('home_prompt_text');

  @override
  ConsumerState<JournalHomePage> createState() => _JournalHomePageState();
}

class _JournalHomePageState extends ConsumerState<JournalHomePage> {
  final _searchController = TextEditingController();
  final _tagController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(journalEntriesProvider);
    final promptState = ref.watch(smartPromptControllerProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 820;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTopSectionHeight = isCompact
            ? constraints.maxHeight * 0.58
            : constraints.maxHeight * 0.5;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxTopSectionHeight),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderCard(
                        onQuickTag: _applyQuickTag,
                        promptText: promptState.prompt,
                        promptError: promptState.errorMessage,
                        promptLoading: promptState.isLoading,
                        onGeneratePrompt: _generateSmartPrompt,
                      ),
                      const SizedBox(height: 16),
                      _FilterPanel(
                        isCompact: isCompact,
                        searchController: _searchController,
                        tagController: _tagController,
                        onSearchChanged: (value) {
                          ref.read(journalSearchQueryProvider.notifier).state =
                              value;
                        },
                        onTagChanged: (value) {
                          ref.read(journalTagFilterProvider.notifier).state =
                              value;
                        },
                        onReset: _resetFilters,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: entriesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const _ErrorState(),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const _EmptyState();
                    }

                    return Column(
                      children: [
                        _EntriesSummary(entriesCount: entries.length),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.separated(
                            key: JournalHomePage.entriesListKey,
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return _EntryCard(
                                entry: entry,
                                onTap: () => _openEntryDetail(entry),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyQuickTag(String tag) {
    _tagController.text = tag;
    ref.read(journalTagFilterProvider.notifier).state = tag;
  }

  void _resetFilters() {
    _searchController.clear();
    _tagController.clear();
    ref.read(journalSearchQueryProvider.notifier).state = '';
    ref.read(journalTagFilterProvider.notifier).state = '';
  }

  Future<void> _openEntryDetail(JournalEntry entry) async {
    final result = await Navigator.of(context).push<JournalEntryDetailResult?>(
      MaterialPageRoute<JournalEntryDetailResult?>(
        builder: (_) => JournalDetailPage(entryId: entry.id),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    ref.invalidate(journalEntriesProvider);

    if (result.deletedEntry != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entry deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              unawaited(_restoreDeletedEntry(result.deletedEntry!));
            },
          ),
        ),
      );
      return;
    }

    if (result.updated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entry updated')));
    }
  }

  Future<void> _restoreDeletedEntry(JournalEntry entry) async {
    await ref.read(journalRepositoryProvider).upsertEntry(entry);
    ref.invalidate(journalEntriesProvider);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entry restored')));
  }

  Future<void> _generateSmartPrompt() async {
    await ref.read(smartPromptControllerProvider.notifier).generatePrompt();
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.isCompact,
    required this.searchController,
    required this.tagController,
    required this.onSearchChanged,
    required this.onTagChanged,
    required this.onReset,
  });

  final bool isCompact;
  final TextEditingController searchController;
  final TextEditingController tagController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTagChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final searchField = TextField(
      key: JournalHomePage.searchFieldKey,
      controller: searchController,
      decoration: const InputDecoration(
        labelText: 'Search entries',
        hintText: 'Title or content',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: onSearchChanged,
    );

    final tagField = TextField(
      key: JournalHomePage.tagFieldKey,
      controller: tagController,
      decoration: const InputDecoration(
        labelText: 'Tag filter',
        hintText: 'wellness',
        prefixIcon: Icon(Icons.tag),
      ),
      onChanged: onTagChanged,
    );

    final resetButton = OutlinedButton(
      onPressed: onReset,
      style: OutlinedButton.styleFrom(
        side: BorderSide.none,
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: const Text('Clear'),
    );

    if (isCompact) {
      return Column(
        children: [
          searchField,
          const SizedBox(height: 10),
          tagField,
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: resetButton),
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: searchField),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: tagField),
        const SizedBox(width: 10),
        resetButton,
      ],
    );
  }
}

class _EntriesSummary extends StatelessWidget {
  const _EntriesSummary({required this.entriesCount});

  final int entriesCount;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '$entriesCount entries',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.onQuickTag,
    required this.promptText,
    required this.promptError,
    required this.promptLoading,
    required this.onGeneratePrompt,
  });

  final ValueChanged<String> onQuickTag;
  final String? promptText;
  final String? promptError;
  final bool promptLoading;
  final Future<void> Function() onGeneratePrompt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      decoration: BoxDecoration(color: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capture today while it is fresh',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap an entry to open details, edit, or delete with undo support.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickTagChip(label: 'wellness', onTap: onQuickTag),
              _QuickTagChip(label: 'work', onTap: onQuickTag),
              _QuickTagChip(label: 'gratitude', onTap: onQuickTag),
            ],
          ),
          const SizedBox(height: 12),
          _SmartPromptPanel(
            promptText: promptText,
            promptError: promptError,
            promptLoading: promptLoading,
            onGeneratePrompt: onGeneratePrompt,
          ),
        ],
      ),
    );
  }
}

class _SmartPromptPanel extends StatelessWidget {
  const _SmartPromptPanel({
    required this.promptText,
    required this.promptError,
    required this.promptLoading,
    required this.onGeneratePrompt,
  });

  final String? promptText;
  final String? promptError;
  final bool promptLoading;
  final Future<void> Function() onGeneratePrompt;

  @override
  Widget build(BuildContext context) {
    final hasPrompt = promptText != null && promptText!.trim().isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Inspire Me',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colorScheme.primary),
            ),
            const Spacer(),
            if (promptLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                key: JournalHomePage.generatePromptButtonKey,
                onPressed: () {
                  unawaited(onGeneratePrompt());
                },
                icon: const Icon(Icons.refresh, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: colorScheme.outline,
              ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            key: ValueKey(hasPrompt ? promptText : 'empty_prompt'),
            hasPrompt
                ? promptText!
                : 'Need a spark? Tap refresh to generate a personalized prompt.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (promptError != null && promptError!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Unable to load prompt right now. Try again later.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.outline, // Subtle error styling
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickTagChip extends StatelessWidget {
  const _QuickTagChip({required this.label, required this.onTap});

  final String label;
  final ValueChanged<String> onTap;

  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        '#$label',
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: () => onTap(label),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    _formatDate(entry.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(entry.content, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.tags
                      .map(
                        (tag) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(tag),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your space to reflect.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture today while it is fresh.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Unable to load entries right now.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
