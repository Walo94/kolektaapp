import 'package:flutter_test/flutter_test.dart';
import 'package:kolekta/app.dart';

void main() {
  testWidgets('App smoke test - renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(KolektaApp());
    // Solo verifica que la app arranca sin errores
    expect(find.byType(KolektaApp), findsOneWidget);
  });
}