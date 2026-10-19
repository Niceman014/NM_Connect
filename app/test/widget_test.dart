import 'package:flutter_test/flutter_test.dart';
import 'package:nm_connect/main.dart';

void main() {
  testWidgets('App boots and shows NM Connect title', (WidgetTester tester) async {
    await tester.pumpWidget(const NmConnectApp());
    // Verifies the app boots and the title is present
    expect(find.text('NM Connect'), findsWidgets);
  });
}