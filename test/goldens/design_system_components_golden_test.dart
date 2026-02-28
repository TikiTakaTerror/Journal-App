import 'package:ai_journal/app/design_system/app_theme.dart';
import 'package:ai_journal/app/design_system/components/collapsible_section.dart';
import 'package:ai_journal/app/design_system/components/empty_state_panel.dart';
import 'package:ai_journal/app/design_system/components/inline_notice.dart';
import 'package:ai_journal/app/design_system/components/journal_entry_card.dart';
import 'package:ai_journal/app/design_system/components/pill_chip.dart';
import 'package:ai_journal/app/design_system/components/primary_action_button.dart';
import 'package:ai_journal/app/design_system/components/section_header.dart';
import 'package:ai_journal/features/journal/domain/models/journal_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const showcaseKey = ValueKey<String>('design_system_showcase');

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpShowcase(
    WidgetTester tester, {
    required ThemeData theme,
    required Brightness platformBrightness,
  }) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        platformBrightness;
    addTearDown(() {
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    await tester.binding.setSurfaceSize(const Size(430, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SafeArea(
            child: RepaintBoundary(
              key: showcaseKey,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: _DesignSystemShowcase(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('design system showcase light', (tester) async {
    await pumpShowcase(
      tester,
      theme: JournalDesignTheme.light(),
      platformBrightness: Brightness.light,
    );

    await expectLater(
      find.byKey(showcaseKey),
      matchesGoldenFile('design_system_components_light.png'),
    );
  });

  testWidgets('design system showcase dark', (tester) async {
    await pumpShowcase(
      tester,
      theme: JournalDesignTheme.dark(),
      platformBrightness: Brightness.dark,
    );

    await expectLater(
      find.byKey(showcaseKey),
      matchesGoldenFile('design_system_components_dark.png'),
    );
  });
}

class _DesignSystemShowcase extends StatelessWidget {
  const _DesignSystemShowcase();

  @override
  Widget build(BuildContext context) {
    final entry = JournalEntry.create(
      id: 'sample-entry',
      title: 'Morning reset',
      content:
          'I went for a short walk before work and noticed my shoulders relax. '
          'Writing this down makes the pattern easier to repeat tomorrow.',
      tags: const ['wellness', 'work'],
      createdAt: DateTime.utc(2026, 2, 26, 12),
      updatedAt: DateTime.utc(2026, 2, 26, 12, 30),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Today',
            subtitle: 'Calm, minimal surfaces with optional AI support.',
            trailing: PillChip(
              label: 'New',
              icon: Icons.add_rounded,
              onTap: () {},
            ),
          ),
          const SizedBox(height: 12),
          const InlineNotice(
            tone: InlineNoticeTone.info,
            message:
                'AI suggestions are optional and only sent to cloud when explicit consent is enabled.',
          ),
          const SizedBox(height: 12),
          JournalEntryCard(entry: entry, onTap: _noop),
          const SizedBox(height: 12),
          const CollapsibleSection(
            title: 'AI Reflection',
            subtitle: 'Optional after save',
            initiallyExpanded: true,
            child: Text(
              'You identified a repeatable routine and a physical signal that improves your day.',
            ),
          ),
          const SizedBox(height: 12),
          EmptyStatePanel(
            icon: Icons.forum_outlined,
            title: 'AI Companion',
            message:
                'Compact panel for follow-up prompts and memory-aware reflections.',
            action: PrimaryActionButton(
              label: 'Open companion',
              expanded: false,
              icon: Icons.auto_awesome_outlined,
              onPressed: _noop,
            ),
          ),
        ],
      ),
    );
  }

  static void _noop() {}
}
