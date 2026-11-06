import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/entry_edit.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';

// 고치기 화면을 열 때의 관리비(지급 전).
final base = EntryDraft(
  kind: EntryKind.planned,
  memberId: 'owner',
  amount: 200000,
  title: '관리비',
  categoryId: 'c-living',
  paymentMethodId: 'p-account',
  dueOn: DateTime(2026, 10, 25),
);

EntryDraft change(
  EntryDraft draft, {
  int? amount,
  String? title,
  DateTime? date,
  String? memo,
}) => EntryDraft(
  kind: draft.kind,
  memberId: draft.memberId,
  amount: amount ?? draft.amount,
  title: title ?? draft.title,
  categoryId: draft.categoryId,
  paymentMethodId: draft.paymentMethodId,
  date: date ?? draft.date,
  dueOn: draft.dueOn,
  memo: memo ?? draft.memo,
);

void main() {
  test('내가 바꾸지 않은 칸은 상대가 그사이 바꾼 값을 지킨다(제목만 고쳐도 상대의 지급 완료가 남는다)', () {
    final paid = change(base, date: DateTime(2026, 10, 25));

    final (:merged, :conflicts) = mergeEntryEdit(
      base: base,
      mine: change(base, title: '관리비(난방)'),
      theirs: paid,
    );

    expect(conflicts, isEmpty);
    expect(merged.title, '관리비(난방)');
    expect(merged.date, DateTime(2026, 10, 25));
  });

  test('나만 바꾼 칸은 내 값이고, 둘 다 같은 값으로 바꾼 칸은 겹침이 아니다', () {
    final (:merged, :conflicts) = mergeEntryEdit(
      base: base,
      mine: change(base, amount: 230000, memo: '난방 포함'),
      theirs: change(base, amount: 230000),
    );

    expect(conflicts, isEmpty);
    expect(merged.amount, 230000);
    expect(merged.memo, '난방 포함');
  });

  test('같은 칸을 둘이 다르게 바꾸면 겹침으로 알리고, 고르면 그 값으로 합친다', () {
    final mine = change(base, amount: 230000, memo: '난방 포함');
    final theirs = change(base, amount: 210000, date: DateTime(2026, 10, 25));

    expect(mergeEntryEdit(base: base, mine: mine, theirs: theirs).conflicts, {
      EntryField.amount,
    });

    final kept = mergeEntryEdit(
      base: base,
      mine: mine,
      theirs: theirs,
      choice: EditConflictChoice.theirs,
    );
    expect(kept.conflicts, isEmpty);
    expect(kept.merged.amount, 210000);
    // 겹치지 않은 칸은 고른 것과 상관없이 합쳐진다.
    expect(kept.merged.memo, '난방 포함');
    expect(kept.merged.date, DateTime(2026, 10, 25));

    final overwritten = mergeEntryEdit(
      base: base,
      mine: mine,
      theirs: theirs,
      choice: EditConflictChoice.mine,
    );
    expect(overwritten.merged.amount, 230000);
    expect(overwritten.merged.date, DateTime(2026, 10, 25));
  });

  test('지급 완료를 내가 끄고 상대가 다른 날로 바꾸면 겹친다', () {
    final paid = change(base, date: DateTime(2026, 10, 20));

    final (:merged, :conflicts) = mergeEntryEdit(
      base: paid,
      mine: base,
      theirs: change(base, date: DateTime(2026, 10, 25)),
    );

    expect(conflicts, {EntryField.date});
    expect(merged.date, isNull);
  });
}
