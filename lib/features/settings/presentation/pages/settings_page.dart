import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/ai/domain/contracts/ai_api_key_store.dart';
import 'package:ai_journal/features/ai/presentation/state/openai_api_key_controller.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:ai_journal/features/settings/domain/models/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  static const Key localOnlyAiSwitchKey = ValueKey<String>(
    'settings_local_only_ai_switch',
  );
  static const Key cloudAiSwitchKey = ValueKey<String>(
    'settings_cloud_ai_switch',
  );
  static const Key notificationsSwitchKey = ValueKey<String>(
    'settings_notifications_switch',
  );
  static const Key darkModeSwitchKey = ValueKey<String>(
    'settings_dark_mode_switch',
  );
  static const Key openAiKeyStatusKey = ValueKey<String>(
    'settings_openai_key_status',
  );
  static const Key openAiSetKeyButtonKey = ValueKey<String>(
    'settings_openai_set_key_button',
  );
  static const Key openAiReplaceKeyButtonKey = ValueKey<String>(
    'settings_openai_replace_key_button',
  );
  static const Key openAiRemoveKeyButtonKey = ValueKey<String>(
    'settings_openai_remove_key_button',
  );
  static const Key openAiApiKeyFieldKey = ValueKey<String>(
    'settings_openai_api_key_field',
  );
  static const Key exportButtonKey = ValueKey<String>('settings_export_button');
  static const Key wipeDataButtonKey = ValueKey<String>(
    'settings_wipe_data_button',
  );

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _exporting = false;
  bool _deletingAll = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final openAiKeyState = ref.watch(openAIApiKeyControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsHeroCard(settings: settings),
        const SizedBox(height: 18),
        Text(
          'Privacy & Security',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        _SettingsSectionCard(
          icon: Icons.shield_moon_outlined,
          title: 'AI Processing',
          subtitle:
              'Control whether journal content stays on-device or can be used with cloud AI services.',
          child: Column(
            children: [
              SwitchListTile(
                key: SettingsPage.localOnlyAiSwitchKey,
                contentPadding: EdgeInsets.zero,
                title: const Text('Use local AI only'),
                subtitle: const Text(
                  'Recommended for maximum privacy. Cloud processing stays disabled.',
                ),
                value: settings.localOnlyAi,
                onChanged: (value) {
                  ref
                      .read(appSettingsControllerProvider.notifier)
                      .setLocalOnlyAi(value);
                },
              ),
              const Divider(height: 8),
              SwitchListTile(
                key: SettingsPage.cloudAiSwitchKey,
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow cloud AI processing'),
                subtitle: Text(
                  settings.localOnlyAi
                      ? 'Disable local-only mode first to enable this.'
                      : 'Requires explicit consent before any cloud call.',
                ),
                value: settings.cloudAiConsent,
                onChanged: settings.localOnlyAi
                    ? null
                    : (value) {
                        _onCloudAiToggle(value);
                      },
              ),
              const Divider(height: 8),
              ListTile(
                key: SettingsPage.openAiKeyStatusKey,
                contentPadding: EdgeInsets.zero,
                title: Text(_openAiKeyTitle(openAiKeyState)),
                subtitle: Text(_openAiKeySubtitle(openAiKeyState)),
                trailing: openAiKeyState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_openAiKeyStatusIcon(openAiKeyState)),
              ),
              if (openAiKeyState.maskedPreview != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Key preview: ${openAiKeyState.maskedPreview}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              if (openAiKeyState.usingStoredKey &&
                  openAiKeyState.storageProtection ==
                      AIApiKeyStorageProtection.localFallback) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Warning: secure storage was unavailable, so the key is stored in local app preferences on this device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              if (openAiKeyState.errorMessage != null &&
                  openAiKeyState.errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    openAiKeyState.errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (openAiKeyState.usingStoredKey)
                    OutlinedButton.icon(
                      key: SettingsPage.openAiReplaceKeyButtonKey,
                      onPressed: openAiKeyState.isSaving
                          ? null
                          : _replaceOpenAiKey,
                      icon: openAiKeyState.isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.key_outlined),
                      label: const Text('Replace key'),
                    )
                  else
                    OutlinedButton.icon(
                      key: SettingsPage.openAiSetKeyButtonKey,
                      onPressed: openAiKeyState.isSaving ? null : _setOpenAiKey,
                      icon: openAiKeyState.isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.key_outlined),
                      label: Text(
                        openAiKeyState.usingDevOverride ? 'Store local key' : 'Set key',
                      ),
                    ),
                  if (openAiKeyState.usingStoredKey)
                    FilledButton.tonalIcon(
                      key: SettingsPage.openAiRemoveKeyButtonKey,
                      onPressed: openAiKeyState.isSaving
                          ? null
                          : _removeOpenAiKey,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove key'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsSectionCard(
          icon: Icons.tune,
          title: 'Experience',
          subtitle: 'Tune behavior, appearance, and reminders.',
          child: Column(
            children: [
              SwitchListTile(
                key: SettingsPage.notificationsSwitchKey,
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily reminder notifications'),
                subtitle: const Text(
                  'Plan your writing cadence (notification scheduling in next phase).',
                ),
                value: settings.notificationsEnabled,
                onChanged: (value) {
                  ref
                      .read(appSettingsControllerProvider.notifier)
                      .setNotificationsEnabled(value);
                },
              ),
              const Divider(height: 8),
              SwitchListTile(
                key: SettingsPage.darkModeSwitchKey,
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark mode'),
                subtitle: const Text(
                  'Mirror your preferred writing environment.',
                ),
                value: settings.darkMode,
                onChanged: (value) {
                  ref
                      .read(appSettingsControllerProvider.notifier)
                      .toggleDarkMode();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsSectionCard(
          icon: Icons.data_object,
          title: 'Data Controls',
          subtitle:
              'Offline-first controls for export and account-free deletion.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                key: SettingsPage.exportButtonKey,
                onPressed: _exporting ? null : _previewMarkdownExport,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: const Text('Preview Markdown export'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                key: SettingsPage.wipeDataButtonKey,
                onPressed: _deletingAll ? null : _deleteAllData,
                icon: _deletingAll
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete all local journal data'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onCloudAiToggle(bool value) async {
    if (!value) {
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setCloudAiConsent(false);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Enable cloud AI processing?'),
          content: const Text(
            'Journal content may be sent to a third-party AI service after this change. '
            'Only enable this if you explicitly consent.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await ref
        .read(appSettingsControllerProvider.notifier)
        .setCloudAiConsent(true);
  }

  String _openAiKeyTitle(OpenAIApiKeyState state) {
    if (state.isLoading) {
      return 'OpenAI key: Checking local key';
    }
    if (state.usingStoredKey) {
      return 'OpenAI key: Stored locally';
    }
    if (state.usingDevOverride) {
      return 'OpenAI key: Using dev override';
    }
    return 'OpenAI key: Missing';
  }

  String _openAiKeySubtitle(OpenAIApiKeyState state) {
    if (state.usingStoredKey) {
      return switch (state.storageProtection) {
        AIApiKeyStorageProtection.secureStorage =>
          'Stored on this device using secure storage.',
        AIApiKeyStorageProtection.localFallback =>
          'Stored on this device with local fallback storage.',
        AIApiKeyStorageProtection.none =>
          'Stored on this device.',
      };
    }

    if (state.usingDevOverride) {
      return 'Loaded from --dart-define / --dart-define-from-file (development override).';
    }

    return 'Add a personal OpenAI API key to enable cloud AI after explicit consent.';
  }

  IconData _openAiKeyStatusIcon(OpenAIApiKeyState state) {
    if (state.usingStoredKey || state.usingDevOverride) {
      return Icons.verified_outlined;
    }
    return Icons.warning_amber_outlined;
  }

  Future<void> _setOpenAiKey() async {
    await _saveOpenAiKeyFlow();
  }

  Future<void> _replaceOpenAiKey() async {
    await _saveOpenAiKeyFlow();
  }

  Future<void> _saveOpenAiKeyFlow() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Store OpenAI API key'),
          content: Form(
            key: formKey,
            child: TextFormField(
              key: SettingsPage.openAiApiKeyFieldKey,
              controller: controller,
              autofocus: true,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'API key',
                hintText: 'sk-...',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter an API key';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Save key'),
            ),
          ],
        );
      },
    );
    if (value == null || value.trim().isEmpty) {
      return;
    }

    await ref.read(openAIApiKeyControllerProvider.notifier).saveKey(value);
    if (!mounted) {
      return;
    }

    final state = ref.read(openAIApiKeyControllerProvider);
    if (state.errorMessage == null || state.errorMessage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OpenAI key stored locally.')),
      );
    }
  }

  Future<void> _removeOpenAiKey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Remove stored OpenAI key?'),
          content: const Text(
            'This removes the locally stored key from this device. Development overrides (if present) may still be detected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await ref.read(openAIApiKeyControllerProvider.notifier).removeKey();
    if (!mounted) {
      return;
    }

    final state = ref.read(openAIApiKeyControllerProvider);
    if (state.errorMessage == null || state.errorMessage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stored OpenAI key removed.')),
      );
    }
  }

  Future<void> _previewMarkdownExport() async {
    setState(() {
      _exporting = true;
    });

    try {
      final entries = await ref.read(journalRepositoryProvider).listEntries();
      if (!mounted) {
        return;
      }

      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No entries available to export yet.')),
        );
        return;
      }

      final markdown = _toMarkdown(entries);
      await showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Markdown Preview'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(child: SelectableText(markdown)),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete all journal data?'),
          content: const Text(
            'This removes all local entries. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _deletingAll = true;
    });

    try {
      final repository = ref.read(journalRepositoryProvider);
      final entries = await repository.listEntries();

      for (final entry in entries) {
        await repository.deleteEntry(entry.id);
      }

      ref.invalidate(journalEntriesProvider);
      ref.invalidate(journalAllEntriesProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entries.length} entries deleted.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingAll = false;
        });
      }
    }
  }

  String _toMarkdown(List<JournalEntry> entries) {
    final buffer = StringBuffer('# AI Journal Export\n\n');

    for (final entry in entries) {
      final date = _formatDate(entry.updatedAt);
      buffer.writeln('## ${entry.title}');
      buffer.writeln('*Updated: $date*');

      if (entry.tags.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Tags: ${entry.tags.map((tag) => '#$tag').join(' ')}');
      }

      buffer.writeln();
      buffer.writeln(entry.content);
      buffer.writeln('\n---\n');
    }

    return buffer.toString().trim();
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _SettingsHeroCard extends StatelessWidget {
  const _SettingsHeroCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Control your journal boundaries',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            settings.localOnlyAi
                ? 'Local-only mode is active. Cloud AI requests are blocked.'
                : 'Cloud AI can be enabled only with explicit consent.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                'No analytics. No account required.',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
