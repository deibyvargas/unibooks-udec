import 'package:flutter_test/flutter_test.dart';
import 'package:unibooks_app/main.dart';

void main() {
  testWidgets('UnibooksApp initialization smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UnibooksApp());
    expect(find.byType(UnibooksApp), findsOneWidget);
  });
}
