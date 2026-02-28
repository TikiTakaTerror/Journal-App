import 'package:ai_journal/app/design_system/app_theme.dart';
import 'package:ai_journal/app/design_system/components/collapsible_section.dart';
import 'package:ai_journal/app/design_system/components/editor_toolbar_button.dart';
import 'package:ai_journal/app/design_system/components/pill_chip.dart';
import 'package:ai_journal/app/design_system/components/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHarness(Widget child) {
    return MaterialApp(
      theme: JournalDesignTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('interactive components respond to taps', (tester) async {
    var chipTapped = false;
    var toolbarTapped = false;
    var primaryTapped = false;

    await tester.pumpWidget(
      buildHarness(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PillChip(
              label: 'Mood',
              icon: Icons.mood_outlined,
              onTap: () => chipTapped = true,
            ),
            const SizedBox(height: 12),
            EditorToolbarButton(
              icon: Icons.format_bold,
              tooltip: 'Bold',
              onPressed: () => toolbarTapped = true,
            ),
            const SizedBox(height: 12),
            PrimaryActionButton(
              label: 'Save',
              expanded: false,
              onPressed: () => primaryTapped = true,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Mood'));
    await tester.tap(find.text('Bold').last);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(chipTapped, isTrue);
    expect(toolbarTapped, isTrue);
    expect(primaryTapped, isTrue);
  });

  testWidgets('primary action button supports keyboard focus and activate', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: JournalDesignTheme.light(),
        home: Scaffold(
          body: FocusTraversalGroup(
            child: Column(
              children: [
                TextButton(onPressed: () {}, child: const Text('First')),
                PrimaryActionButton(
                  label: 'Continue',
                  expanded: false,
                  onPressed: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('collapsible section toggles content visibility', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        const CollapsibleSection(
          title: 'Reflection',
          subtitle: 'Optional',
          child: Text('Collapsed content'),
        ),
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsOneWidget);

    await tester.tap(find.text('Reflection'));
    await tester.pumpAndSettle();
    expect(find.text('Collapsed content'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);

    await tester.tap(find.text('Reflection'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });
}
