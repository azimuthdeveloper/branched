import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:branched/git_engine/git_models.dart';
import 'package:branched/features/auth/credentials_dialog.dart';

void main() {
  testWidgets('Credentials Dialog - displays fields and returns value on sign in', (WidgetTester tester) async {
    GitAuthCredentials? result;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showCredentialsDialog(
                    context,
                    'https://github.com/test/repo.git',
                    failedUsername: 'olduser',
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to show dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('Authentication Required'), findsOneWidget);
    expect(find.text('https://github.com/test/repo.git'), findsOneWidget);
    expect(find.text('The previous credentials were rejected. Please try again.'), findsOneWidget);

    // Find input fields
    final usernameField = find.byKey(const Key('auth_username_field'));
    final passwordField = find.byKey(const Key('auth_password_field'));
    expect(usernameField, findsOneWidget);
    expect(passwordField, findsOneWidget);

    // Pre-filled value check
    expect(tester.widget<TextField>(usernameField).controller?.text, 'olduser');

    // Enter values
    await tester.enterText(usernameField, 'newuser');
    await tester.enterText(passwordField, 'newpass');
    await tester.pump();

    // Tap OK button
    await tester.tap(find.byKey(const Key('auth_ok_button')));
    await tester.pumpAndSettle();

    // Verify result
    expect(result, isNotNull);
    expect(result!.username, 'newuser');
    expect(result!.password, 'newpass');
  });

  testWidgets('Credentials Dialog - returns null on cancel', (WidgetTester tester) async {
    GitAuthCredentials? result;
    bool dialogReturned = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showCredentialsDialog(
                    context,
                    'https://github.com/test/repo.git',
                  );
                  dialogReturned = true;
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to show dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Tap Cancel button
    await tester.tap(find.byKey(const Key('auth_cancel_button')));
    await tester.pumpAndSettle();

    // Verify result
    expect(dialogReturned, isTrue);
    expect(result, isNull);
  });
}
