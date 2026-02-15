import 'package:ai_journal/app/app.dart';
import 'package:ai_journal/features/journal/presentation/pages/journal_editor_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots into journal editor page', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JournalApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(JournalEditorPage.titleFieldKey), findsOneWidget);
    expect(find.byKey(JournalEditorPage.contentFieldKey), findsOneWidget);
  });
}
