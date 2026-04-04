import 'package:flutter_test/flutter_test.dart';
import 'package:waidblick/main.dart';

void main() {
  testWidgets('App startet', (WidgetTester tester) async {
    await tester.pumpWidget(const WaidblickApp());
    expect(find.text('WAIDBLICK'), findsWidgets);
  });
}
