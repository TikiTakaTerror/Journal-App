import 'package:ai_journal/app/providers.dart';
import 'package:ai_journal/features/journal/presentation/pages/journal_editor_page.dart';
import 'package:ai_journal/features/journal/presentation/pages/journal_home_page.dart';
import 'package:ai_journal/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainShellPage extends ConsumerStatefulWidget {
  const MainShellPage({super.key});

  static const Key createEntryFabKey = ValueKey<String>('create_entry_fab');
  static const Key themeToggleButtonKey = ValueKey<String>('theme_toggle_button');
  static const Key navigationBarKey = ValueKey<String>('main_navigation_bar');

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final isWideLayout = MediaQuery.sizeOf(context).width >= 960;

    final pages = <Widget>[
      const JournalHomePage(),
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Journal' : 'Settings'),
        actions: [
          IconButton(
            key: MainShellPage.themeToggleButtonKey,
            tooltip: 'Toggle theme',
            onPressed: () {
              ref.read(appSettingsControllerProvider.notifier).toggleDarkMode();
            },
            icon: Icon(settings.darkMode ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: isWideLayout
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.menu_book_outlined),
                          selectedIcon: Icon(Icons.menu_book),
                          label: Text('Journal'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.shield_outlined),
                          selectedIcon: Icon(Icons.shield),
                          label: Text('Settings'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: KeyedSubtree(
                          key: ValueKey<int>(_selectedIndex),
                          child: pages[_selectedIndex],
                        ),
                      ),
                    ),
                  ],
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedIndex),
                    child: pages[_selectedIndex],
                  ),
                ),
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              key: MainShellPage.createEntryFabKey,
              onPressed: _openNewEntryEditor,
              icon: const Icon(Icons.edit_note),
              label: const Text('New Entry'),
            )
          : null,
      bottomNavigationBar: isWideLayout
          ? null
          : NavigationBar(
              key: MainShellPage.navigationBarKey,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Journal',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shield_outlined),
                  selectedIcon: Icon(Icons.shield),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  Future<void> _openNewEntryEditor() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const JournalEditorPage(),
      ),
    );

    if (saved == true && mounted) {
      ref.invalidate(journalEntriesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved')),
      );
    }
  }
}
