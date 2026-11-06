import 'ledger_entries.dart';

/// 고치기가 겹치는지 견주는 항목의 칸. 종류는 고칠 수 없어서 넣지 않는다.
enum EntryField {
  member,
  amount,
  title,
  category,
  paymentMethod,
  card,
  date,
  dueOn,
  memo,
}

/// 상대와 같은 칸을 다르게 고쳤을 때 어느 쪽 값을 남길지.
enum EditConflictChoice {
  /// 내가 저장하려던 값.
  mine,

  /// 그사이 상대가 저장한 값.
  theirs,
}

/// 고치기 화면을 연 사이 상대가 같은 칸([fields])을 다르게 고쳐서 저장하지 않았다.
/// 화면은 상대 값([theirs])과 내 값([mine])을 칸마다 보여주고 [EditConflictChoice]를 골라 다시 저장한다.
class EntryEditConflict implements Exception {
  const EntryEditConflict({
    required this.fields,
    required this.theirs,
    required this.mine,
  });

  final Set<EntryField> fields;

  /// 지금 서버에 있는 상대의 값.
  final EntryDraft theirs;

  /// 내가 저장하려던 값.
  final EntryDraft mine;

  @override
  String toString() => 'EntryEditConflict($fields)';
}

/// 고치기 화면을 열 때의 값 [base], 저장하려는 값 [mine], 지금 서버의 값 [theirs]를 칸마다 견주어 합친다(3-way).
///
/// - 내가 바꾸지 않은 칸은 상대 값을 둔다(그사이 상대가 바꿨으면 그 값이 남는다).
/// - 나만 바꿨거나, 둘 다 같은 값으로 바꾼 칸은 내 값이다.
/// - 둘 다 다르게 바꾼 칸은 [choice]대로 고르고, [choice]가 없으면 [conflicts]에 넣는다(값은 내 것으로 둔다).
///
/// 종류는 [mine]을 따른다(고치기에서는 바뀌지 않는다).
({EntryDraft merged, Set<EntryField> conflicts}) mergeEntryEdit({
  required EntryDraft base,
  required EntryDraft mine,
  required EntryDraft theirs,
  EditConflictChoice? choice,
}) {
  final conflicts = <EntryField>{};
  T pick<T>(EntryField field, T Function(EntryDraft draft) of) {
    final (before, my, their) = (of(base), of(mine), of(theirs));
    if (my == before) return their;
    if (their == before || their == my) return my;
    if (choice == null) conflicts.add(field);
    return choice == EditConflictChoice.theirs ? their : my;
  }

  final merged = EntryDraft(
    kind: mine.kind,
    memberId: pick(EntryField.member, (d) => d.memberId),
    amount: pick(EntryField.amount, (d) => d.amount),
    title: pick(EntryField.title, (d) => d.title),
    categoryId: pick(EntryField.category, (d) => d.categoryId),
    paymentMethodId: pick(EntryField.paymentMethod, (d) => d.paymentMethodId),
    cardId: pick(EntryField.card, (d) => d.cardId),
    date: pick(EntryField.date, (d) => d.date),
    dueOn: pick(EntryField.dueOn, (d) => d.dueOn),
    memo: pick(EntryField.memo, (d) => d.memo),
  );
  return (merged: merged, conflicts: conflicts);
}
