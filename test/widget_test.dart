import 'package:flutter_test/flutter_test.dart';
import 'package:aroma/main.dart';

void main() {
  testWidgets('Aroma Cafe app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const AromaCafeApp());
    expect(find.text('AROMA TEA CAFE'), findsOneWidget);
  });
}
