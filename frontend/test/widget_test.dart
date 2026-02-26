import 'package:flutter_test/flutter_test.dart';
import 'package:agrichain_app/main.dart';

void main() {
  testWidgets('AgriChain app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AgriChainApp());
    expect(find.text('AgriChain'), findsOneWidget);
  });
}
