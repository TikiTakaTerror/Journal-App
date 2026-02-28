import 'dart:async';

import 'package:ai_journal/app/design_system/components/app_surface_card.dart';
import 'package:ai_journal/app/design_system/components/inline_notice.dart';
import 'package:ai_journal/app/design_system/components/pill_chip.dart';
import 'package:ai_journal/app/design_system/components/section_header.dart';
import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/ai/domain/models/ai_chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AICompanionSheet extends ConsumerStatefulWidget {
  const AICompanionSheet({super.key});

  @override
  ConsumerState<AICompanionSheet> createState() => _AICompanionSheetState();
}

class _AICompanionSheetState extends ConsumerState<AICompanionSheet> {
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiCompanionControllerProvider);
    final height = MediaQuery.sizeOf(context).height * 0.74;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'AI Companion',
                      subtitle: state.cloudAvailable
                          ? 'Compact chat with local memory. Cloud AI only runs with your consent + key.'
                          : 'Local memory is available. Cloud AI is currently disabled.',
                      trailing: IconButton(
                        tooltip: 'Refresh memory',
                        onPressed: state.isLoading
                            ? null
                            : () {
                                unawaited(
                                  ref
                                      .read(aiCompanionControllerProvider.notifier)
                                      .load(),
                                );
                              },
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const InlineNotice(
                      tone: InlineNoticeTone.info,
                      message:
                          'Supportive prompts only. Not therapy, medical advice, or crisis support.',
                    ),
                    if (state.memorySummary.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      CollapsibleMemorySummary(summary: state.memorySummary),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Conversation', style: Theme.of(context).textTheme.titleSmall),
                          const Spacer(),
                          if (state.relevantEntriesCount > 0)
                            Text(
                              '${state.relevantEntriesCount} entries used',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InlineNotice(
                            tone: InlineNoticeTone.error,
                            message: state.errorMessage!,
                            action: state.retryable
                                ? TextButton(
                                    onPressed: () {
                                      unawaited(
                                        ref
                                            .read(aiCompanionControllerProvider.notifier)
                                            .retryLast(),
                                      );
                                    },
                                    child: const Text('Retry'),
                                  )
                                : null,
                          ),
                        ),
                      Expanded(
                        child: state.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : state.messages.isEmpty
                                ? _EmptyCompanionConversation(
                                    enabled: state.cloudAvailable,
                                    onPresetTap: _setPreset,
                                  )
                                : ListView.separated(
                                    reverse: false,
                                    itemCount: state.messages.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final message = state.messages[index];
                                      return _ChatBubble(message: message);
                                    },
                                  ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              minLines: 1,
                              maxLines: 4,
                              enabled: !state.isSending,
                              decoration: InputDecoration(
                                labelText: 'Message',
                                hintText: state.cloudAvailable
                                    ? 'Ask for perspective on a recent pattern...'
                                    : 'Enable cloud AI in Settings to chat',
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: state.isSending ? null : _send,
                            icon: state.isSending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            label: const Text('Send'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setPreset(String value) {
    _inputController.text = value;
    _inputController.selection = TextSelection.collapsed(
      offset: _inputController.text.length,
    );
  }

  Future<void> _send() async {
    final value = _inputController.text.trim();
    if (value.isEmpty) {
      return;
    }
    _inputController.clear();
    await ref.read(aiCompanionControllerProvider.notifier).sendMessage(value);
  }
}

class CollapsibleMemorySummary extends StatefulWidget {
  const CollapsibleMemorySummary({super.key, required this.summary});

  final String summary;

  @override
  State<CollapsibleMemorySummary> createState() => _CollapsibleMemorySummaryState();
}

class _CollapsibleMemorySummaryState extends State<CollapsibleMemorySummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.memory_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Local memory summary',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.summary,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCompanionConversation extends StatelessWidget {
  const _EmptyCompanionConversation({
    required this.enabled,
    required this.onPresetTap,
  });

  final bool enabled;
  final ValueChanged<String> onPresetTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            enabled ? 'Start a short check-in' : 'Cloud AI is disabled',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (enabled)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                PillChip(
                  label: 'Ask for perspective',
                  icon: Icons.lightbulb_outline,
                  onTap: () => onPresetTap(
                    'Help me reflect on a pattern I noticed this week.',
                  ),
                ),
                PillChip(
                  label: 'Plan next step',
                  icon: Icons.flag_outlined,
                  onTap: () => onPresetTap(
                    'What is one practical next step I can take tomorrow?',
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Turn off local-only mode, enable cloud AI consent, and add an API key in Settings to use companion chat.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final AIChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AIChatRole.user;
    final scheme = Theme.of(context).colorScheme;
    final bg = isUser
        ? scheme.primaryContainer
        : Color.alphaBlend(
            scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            scheme.surface,
          );
    final fg = isUser ? scheme.onPrimaryContainer : scheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? 'You' : 'Companion',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                message.content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
