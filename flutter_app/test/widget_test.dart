import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aura_finance_prm393/main.dart';

void main() {
  testWidgets('AuraFinanceApp smoke test', (WidgetTester tester) async {
    final financeProvider = FinanceProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: financeProvider,
        child: const AuraFinanceApp(),
      ),
    );
    expect(find.byType(AuraFinanceApp), findsOneWidget);
  });
}
