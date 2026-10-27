import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
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

/// 휠을 [items]칸 굴린다. 양수면 아래 칸(다음 해·다음 달)으로 간다.
Future<void> roll(WidgetTester tester, Key wheel, int items) async {
  await tester.drag(
    find.byKey(wheel),
    Offset(0, -monthPickerItemExtent * items),
  );
  await tester.pumpAndSettle();
}

String? title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('month-picker-title'))).data;

void main() {
  testWidgets('보고 있는 연·월로 열고, 휠을 굴려 완료하면 그 달을 돌려주며 닫힌다', (tester) async {
    YearMonth? result;
    await pumpPicker(tester, onResult: (month) => result = month);
    expect(title(tester), '2026년 10월');

    await roll(tester, const Key('month-picker-years'), 1);
    await roll(tester, const Key('month-picker-months'), -7);
    expect(title(tester), '2027년 3월');
    await tester.tap(find.byKey(const Key('month-picker-done')));
    await tester.pumpAndSettle();

    expect(result, const YearMonth(2027, 3));
    expect(find.byType(MonthPickerSheet), findsNothing);
  });

  testWidgets('휠을 굴렸어도 취소하면 null을 돌려준다', (tester) async {
    YearMonth? result = const YearMonth(2000, 1);
    await pumpPicker(tester, onResult: (month) => result = month);

    await roll(tester, const Key('month-picker-months'), 2);
    await tester.tap(find.byKey(const Key('month-picker-cancel')));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('화면 읽기 도구는 휠을 연도·월 값으로 읽고 조절로 한 칸씩 옮길 수 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPicker(tester, onResult: (_) {});

    expect(
      tester.getSemantics(find.byKey(const Key('month-picker-years'))),
      isSemantics(
        label: '연도',
        value: '2026년',
        increasedValue: '2027년',
        decreasedValue: '2025년',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('month-picker-months'))),
      isSemantics(label: '월', value: '10월', hasIncreaseAction: true),
    );
    semantics.dispose();
  });
}
