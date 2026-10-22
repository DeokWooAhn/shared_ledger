import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/widget/wallet_glyph.dart';

void main() {
  testWidgets('지갑 모양을 정해진 크기로 그린다', (tester) async {
    await tester.pumpWidget(
      const Center(child: WalletGlyph(size: 42, color: Colors.white)),
    );

    expect(tester.getSize(find.byType(WalletGlyph)), const Size(42, 42));
  });
}
