import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recruiter_talentbay/core/widgets/app_dialogs.dart';

void main() {
  testWidgets('Delete account confirmation dialog displays correct warning text and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDeleteAccountConfirmationDialog(context),
              child: const Text('OPEN DIALOG'),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('OPEN DIALOG'));
    await tester.pumpAndSettle();

    // Verify dialog title, warning body, and action buttons
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(
      find.text(
        'Deleting your account will permanently remove your TalentBay account and associated personal data. This action cannot be undone.',
      ),
      findsOneWidget,
    );
    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('DELETE ACCOUNT'), findsOneWidget);

    // Tap cancel and verify dialog closes
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsNothing);
  });
}

