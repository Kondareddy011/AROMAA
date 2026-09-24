import 'package:flutter_test/flutter_test.dart';
import 'package:aroma/main.dart';

void main() {
  testWidgets('Aroma Cafe app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const AromaaCafeApp());
    expect(find.text('AROMAA CAFE'), findsOneWidget);
  });
}
