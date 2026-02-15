import 'package:ai_journal/features/journal/presentation/pages/journal_editor_page.dart';
import 'package:flutter/material.dart';

class JournalApp extends StatelessWidget {
  const JournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Journal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF0F766E),
        ),
        useMaterial3: true,
      ),
      home: const JournalEditorPage(),
    );
  }
}
