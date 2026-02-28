import 'dart:async';

import 'package:ai_journal/app/design_system/components/app_surface_card.dart';
import 'package:ai_journal/app/design_system/components/empty_state_panel.dart';
import 'package:ai_journal/app/design_system/components/inline_notice.dart';
import 'package:ai_journal/app/design_system/components/journal_entry_card.dart';
import 'package:ai_journal/app/design_system/components/pill_chip.dart';
import 'package:ai_journal/app/design_system/components/section_header.dart';
import 'package:ai_journal/app/design_system/tokens/spacing.dart';
import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/ai/presentation/state/smart_prompt_state.dart';
import 'package:ai_journal/features/ai/presentation/widgets/ai_companion_sheet.dart';
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
    final isCompact = MediaQuery.sizeOf(context).width < 860;

    return LayoutBuilder(
      builder: (context, constraints) {
        final topMaxHeight = constraints.maxHeight * (isCompact ? 0.62 : 0.52);

        return Padding(
          padding: AppSpace.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: topMaxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TodayHeaderCard(
                        promptState: promptState,
                        onQuickTag: _applyQuickTag,
                        onGeneratePrompt: _generateSmartPrompt,
                        onRetryPrompt: _retrySmartPrompt,
                        onOpenCompanion: _openCompanionSheet,
                      ),
                      const SizedBox(height: AppSpace.md),
                      _FilterBar(
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
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: entriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const _EntriesLoadErrorState(),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const _EmptyJournalState();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _EntriesSummary(entriesCount: entries.length),
                        const SizedBox(height: AppSpace.sm),
                        Expanded(
                          child: ListView.separated(
                            key: JournalHomePage.entriesListKey,
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpace.sm),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return JournalEntryCard(
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

  Future<void> _retrySmartPrompt() async {
    await ref.read(smartPromptControllerProvider.notifier).retryLastPrompt();
  }

  Future<void> _openCompanionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => const AICompanionSheet(),
    );
  }
}

class _TodayHeaderCard extends StatelessWidget {
  const _TodayHeaderCard({
    required this.promptState,
    required this.onQuickTag,
    required this.onGeneratePrompt,
    required this.onRetryPrompt,
    required this.onOpenCompanion,
  });

  final SmartPromptState promptState;
  final ValueChanged<String> onQuickTag;
  final Future<void> Function() onGeneratePrompt;
  final Future<void> Function() onRetryPrompt;
  final Future<void> Function() onOpenCompanion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppSurfaceCard(
      tint: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.03),
        scheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Today',
            subtitle: 'Write first. Use AI only when it helps you move.',
            trailing: FilledButton.tonalIcon(
              onPressed: () {
                unawaited(onOpenCompanion());
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Companion'),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickTagChip(label: 'wellness', onTap: onQuickTag),
              _QuickTagChip(label: 'work', onTap: onQuickTag),
              _QuickTagChip(label: 'gratitude', onTap: onQuickTag),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          _SmartPromptPanel(
            promptState: promptState,
            onGeneratePrompt: onGeneratePrompt,
            onRetryPrompt: onRetryPrompt,
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
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
        prefixIcon: Icon(Icons.local_offer_outlined),
      ),
      onChanged: onTagChanged,
    );

    final resetButton = OutlinedButton.icon(
      onPressed: onReset,
      icon: const Icon(Icons.refresh),
      label: const Text('Reset'),
    );

    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: isCompact
          ? Column(
              children: [
                searchField,
                const SizedBox(height: 10),
                tagField,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: resetButton),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: tagField),
                const SizedBox(width: 10),
                resetButton,
              ],
            ),
    );
  }
}

class _EntriesSummary extends StatelessWidget {
  const _EntriesSummary({required this.entriesCount});

  final int entriesCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$entriesCount entries', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 8),
        Text(
          'Local-first journal archive',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SmartPromptPanel extends StatelessWidget {
  const _SmartPromptPanel({
    required this.promptState,
    required this.onGeneratePrompt,
    required this.onRetryPrompt,
  });

  final SmartPromptState promptState;
  final Future<void> Function() onGeneratePrompt;
  final Future<void> Function() onRetryPrompt;

  @override
  Widget build(BuildContext context) {
    final hasPrompt = promptState.displayPrompt != null &&
        promptState.displayPrompt!.trim().isNotEmpty;
    final promptText = promptState.displayPrompt ??
        'Generate a focused prompt based on recent themes in your journal.';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      tint: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prompt Companion',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FilledButton.tonalIcon(
                key: JournalHomePage.generatePromptButtonKey,
                onPressed: promptState.isLoading
                    ? null
                    : () {
                        unawaited(onGeneratePrompt());
                      },
                icon: promptState.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt),
                label: Text(hasPrompt ? 'Refresh' : 'Generate'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            key: JournalHomePage.promptTextKey,
            promptText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (promptState.errorMessage != null && promptState.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            InlineNotice(
              tone: InlineNoticeTone.error,
              message: promptState.errorMessage!,
              action: promptState.retryable
                  ? TextButton(
                      onPressed: () {
                        unawaited(onRetryPrompt());
                      },
                      child: const Text('Retry'),
                    )
                  : null,
            ),
          ] else if (promptState.isLoading && hasPrompt) ...[
            const SizedBox(height: 8),
            const InlineNotice(
              tone: InlineNoticeTone.info,
              message: 'Refreshing prompt while keeping your last suggestion visible.',
              icon: Icons.hourglass_empty,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickTagChip extends StatelessWidget {
  const _QuickTagChip({required this.label, required this.onTap});

  final String label;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return PillChip(
      label: '#$label',
      icon: Icons.local_offer_outlined,
      onTap: () => onTap(label),
    );
  }
}

class _EmptyJournalState extends StatelessWidget {
  const _EmptyJournalState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: SizedBox(
                width: 420,
                child: const EmptyStatePanel(
                  icon: Icons.edit_note,
                  title: 'No journal entries yet.',
                  message:
                      'Press “New Entry” to start writing. AI stays optional and your entries stay local-first.',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EntriesLoadErrorState extends StatelessWidget {
  const _EntriesLoadErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 420,
        child: const EmptyStatePanel(
          icon: Icons.inbox_outlined,
          title: 'Unable to load entries right now.',
          message: 'Try again in a moment. Your local data has not been changed.',
        ),
      ),
    );
  }
}
