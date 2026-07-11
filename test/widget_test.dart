import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:branched/main.dart';
import 'package:branched/core/locator.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    setupLocator();
  });

  testWidgets('Smoke test - FurcateApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const FurcateApp());
    await tester.pumpAndSettle();

    // Verify it renders the welcome screen initially (since no repo is open)
    expect(find.text('Furcate'), findsOneWidget);
    expect(find.text('RECENT REPOSITORIES'), findsOneWidget);
  });
}
