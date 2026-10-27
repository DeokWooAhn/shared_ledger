import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/category.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/feature/entries/entry_list.dart';

PlannedExpense planned(
  String title,
  String categoryId,
  int? amount, {
  bool paid = false,
}) => PlannedExpense(
  id: title,
  categoryId: categoryId,
  memberId: 'owner',
  title: title,
  paymentMethodId: 'p1',
  amount: amount,
  paidOn: paid ? DateTime(2026, 10, 5) : null,
);

ExtraExpense extra(String title, int amount, [int? day]) => ExtraExpense(
  id: title,
  memberId: 'owner',
  title: title,
  paymentMethodId: 'p1',
  amount: amount,
  spentOn: day == null ? null : DateTime(2026, 10, day),
);

void main() {
  const categories = [
    Category(id: 'c-invest', name: '저축/투자', countsAsSaving: true),
    Category(id: 'c-interest', name: '대출이자'),
    Category(id: 'c-living', name: '소비'),
  ];

  group('기본 월 지출 목록', () {
    final ledger = MonthLedger(
      plannedExpenses: [
        planned('통신비', 'c-living', 98000, paid: true),
        planned('관리비', 'c-living', null),
        planned('적금', 'c-invest', 500000, paid: true),
        planned('ISA', 'c-invest', 300000),
        planned('예전 분류', 'c-deleted', 10000, paid: true),
      ],
    );
    final list = EntryList.of(
      EntryKind.planned,
      ledger,
      categories: categories,
    );

    test('설정의 분류 순서로 묶고, 항목이 없는 분류는 빼며, 지워진 분류는 맨 뒤에 모은다', () {
      expect(list.groups.map((g) => g.title), ['저축/투자', '소비', '분류 없음']);
      expect(list.groups.map((g) => g.key), ['c-invest', 'c-living', 'none']);
      expect(list.groups.first.countsAsSaving, isTrue);
      expect(list.groups[1].countsAsSaving, isFalse);
    });

    test('묶음 안은 제목 순서이고, 소계는 금액 미정을 0원으로 친다', () {
      final living = list.groups[1];

      expect(living.entries.map((e) => e.id), ['관리비', '통신비']);
      expect(living.total, 98000);
      expect(list.groups.first.entries.map((e) => e.id), ['ISA', '적금']);
    });

    test('건수·합계·지급 전 건수를 센다', () {
      expect(list.count, 5);
      expect(list.total, 908000);
      expect(list.unpaidCount, 2);
      expect(list.isEmpty, isFalse);
    });
  });

  group('다른 종류의 목록', () {
    test('제목 없는 한 묶음이고, 날짜가 늦은 것부터, 날짜 없는 항목은 맨 뒤다', () {
      final ledger = MonthLedger(
        extraExpenses: [
          extra('병원', 30000, 3),
          extra('간식', 5000),
          extra('장보기', 86000, 18),
          extra('책', 12000, 18),
        ],
      );

      final list = EntryList.of(
        EntryKind.extra,
        ledger,
        categories: categories,
      );

      expect(list.groups, hasLength(1));
      expect(list.groups.single.title, isNull);
      expect(list.groups.single.entries.map((e) => e.id), [
        '장보기',
        '책',
        '병원',
        '간식',
      ]);
      expect(list.total, 133000);
      expect(list.unpaidCount, 0);
    });

    test('항목이 없으면 묶음도 없고 비어 있다', () {
      final list = EntryList.of(
        EntryKind.income,
        const MonthLedger(),
        categories: categories,
      );

      expect(list.groups, isEmpty);
      expect(list.isEmpty, isTrue);
      expect(list.total, 0);
    });
  });
}
