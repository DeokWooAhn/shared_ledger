import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/trashed_entry.dart';
import 'package:shared_ledger/domain/model/year_month.dart';

const october = YearMonth(2026, 10);

final fromTemplate = PlannedExpense(
  id: 'tpl-rent',
  categoryId: 'c1',
  memberId: 'owner',
  title: '월세',
  paymentMethodId: 'p1',
  amount: 500000,
  dueOn: DateTime(2026, 10, 25),
);

/// 지금 있는 반복 설정 id. [fromTemplate]의 반복 설정만 있다.
const templateIds = {'tpl-rent'};

const addedByHand = PlannedExpense(
  id: 'manual',
  categoryId: 'c1',
  memberId: 'owner',
  title: '경조사',
  paymentMethodId: 'p1',
  amount: 100000,
);

void main() {
  group('휴지통에 남길 항목', () {
    test('반복 설정이 남아 있는 이번 달·다음 달·그 뒤 달의 고정 지출은 남긴다', () {
      for (final month in [october, october.next, october.next.next]) {
        expect(
          staysInTrash(
            fromTemplate,
            month: month,
            thisMonth: october,
            templateIds: templateIds,
          ),
          isTrue,
          reason: '$month',
        );
      }
    });

    test('지난 달은 다시 만들지 않아서 지울 수 있다', () {
      expect(
        staysInTrash(
          fromTemplate,
          month: october.previous,
          thisMonth: october,
          templateIds: templateIds,
        ),
        isFalse,
      );
    });

    test('그만한 고정 지출(반복 설정이 지워짐)은 다시 만들지 않아서 이번 달이어도 지울 수 있다', () {
      expect(
        staysInTrash(
          fromTemplate,
          month: october,
          thisMonth: october,
          templateIds: const {},
        ),
        isFalse,
      );
    });

    test('직접 더한 고정 지출과 다른 종류는 지울 수 있다', () {
      const extra = ExtraExpense(
        id: 'e1',
        memberId: 'owner',
        title: '점심',
        paymentMethodId: 'p1',
        amount: 12000,
      );
      expect(
        staysInTrash(
          addedByHand,
          month: october,
          thisMonth: october,
          templateIds: templateIds,
        ),
        isFalse,
      );
      expect(
        staysInTrash(
          extra,
          month: october,
          thisMonth: october,
          templateIds: templateIds,
        ),
        isFalse,
      );
    });
  });

  test('그달 고정 지출 id에는 휴지통에 든 고정 지출도 들어간다', () {
    final ledger = MonthLedger(
      plannedExpenses: const [addedByHand],
      trashed: [TrashedEntry(entry: fromTemplate)],
    );

    expect(ledger.plannedIds, {'manual', 'tpl-rent'});
  });
}
