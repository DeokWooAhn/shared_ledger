import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/year_month.dart';
import 'package:shared_ledger/core/widget/month_picker_sheet.dart';

/// 단추로 시트를 열고, 닫힐 때 돌려준 달을 [onResult]로 넘긴다.
Future<void> pumpPicker(
  WidgetTester tester, {
  required ValueChanged<YearMonth?> onResult,
  YearMonth selected = const YearMonth(2026, 10),
  YearMonth current = const YearMonth(2026, 10),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () async => onResult(
                await showMonthPicker(
                  context,
                  selected: selected,
                  current: current,
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('보고 있는 해로 열고, 해를 넘겨 달을 누르면 그 달을 돌려주며 닫힌다', (tester) async {
    YearMonth? result;
    await pumpPicker(tester, onResult: (month) => result = month);
    expect(find.text('2026년'), findsOneWidget);

    await tester.tap(find.byKey(const Key('month-picker-next-year')));
    await tester.pump();
    expect(find.text('2027년'), findsOneWidget);
    await tester.tap(find.byKey(const Key('month-picker-3')));
    await tester.pumpAndSettle();

    expect(result, const YearMonth(2027, 3));
    expect(find.byType(MonthPickerSheet), findsNothing);
  });

  testWidgets('고르지 않고 닫으면 null을 돌려준다', (tester) async {
    YearMonth? result = const YearMonth(2000, 1);
    await pumpPicker(tester, onResult: (month) => result = month);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('화면 읽기 도구는 보고 있는 달을 골라진 것으로, 이번 달을 이번 달로 읽는다', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPicker(
      tester,
      onResult: (_) {},
      selected: const YearMonth(2026, 3),
      current: const YearMonth(2026, 10),
    );

    expect(
      tester.getSemantics(find.byKey(const Key('month-picker-3'))),
      matchesSemantics(
        label: '2026년 3월',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('month-picker-10'))).label,
      '2026년 10월, 이번 달',
    );
    semantics.dispose();
  });
}
