import 'package:flutter_test/flutter_test.dart';
import 'package:certibridge/main.dart';

void main() {
  testWidgets('CertiBridgeApp launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CertiBridgeApp());
    expect(find.text('CertiBridge'), findsWidgets);
  });
}
