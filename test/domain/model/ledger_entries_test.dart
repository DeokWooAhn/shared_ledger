import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';

void main() {
  group('입력 검사', () {
    test('제목은 40자(UTF-16 단위), 메모는 200자를 넘으면 알린다', () {
      EntryDraft draft({String title = '간식', String? memo}) => EntryDraft(
        kind: EntryKind.extra,
        memberId: 'owner',
        amount: 1000,
        title: title,
        paymentMethodId: 'p1',
        memo: memo,
      );

      expect(entryProblemsOf(draft(title: '가' * 40)), isEmpty);
      expect(entryProblemsOf(draft(title: '가' * 41)), {
        EntryProblem.titleTooLong,
      });
      // 보안 규칙처럼 이모지 하나를 두 글자로 센다.
      expect(entryProblemsOf(draft(title: '🍚' * 21)), {
        EntryProblem.titleTooLong,
      });
      expect(entryProblemsOf(draft(memo: '가' * 200)), isEmpty);
      expect(entryProblemsOf(draft(memo: '가' * 201)), {
        EntryProblem.memoTooLong,
      });
    });

    test('금액은 0원부터 받고, 음수면 알린다', () {
      EntryDraft draft(int amount) => EntryDraft(
        kind: EntryKind.extra,
        memberId: 'owner',
        amount: amount,
        title: '간식',
        paymentMethodId: 'p1',
      );

      expect(entryProblemsOf(draft(0)), isEmpty);
      expect(entryProblemsOf(draft(-1)), {EntryProblem.amountNegative});
    });
  });
}
