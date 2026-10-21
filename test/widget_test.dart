import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/app.dart';

void main() {
  testWidgets('앱이 첫 화면을 띄운다', (tester) async {
    await tester.pumpWidget(const SharedLedgerApp());

    expect(find.text('심플 공유 가계부'), findsOneWidget);
  });
}
