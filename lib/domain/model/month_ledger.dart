import 'ledger_entries.dart';
import 'trashed_entry.dart';

/// 한 달치 가계부 데이터.
///
/// 넘긴 목록을 복사하지 않고 그대로 갖는다(테스트가 `const`로 만들 수 있게). 그래서 만든 뒤 목록을 고치면 값이 바뀌므로,
/// 바꿀 수 없는 목록(`const`나 `List.unmodifiable`)을 넘긴다. 앱에서 만드는 곳(Firestore 변환 `monthLedgerFromFirestore`)이 그렇게 한다.
class MonthLedger {
  const MonthLedger({
    this.incomes = const [],
    this.fixedIncomes = const [],
    this.plannedExpenses = const [],
    this.extraExpenses = const [],
    this.cardBills = const [],
    this.trashed = const [],
    Set<String> plannedIds = const {},
    Set<String> fixedIncomeIds = const {},
    this.unsentIds = const {},
  }) : _plannedIds = plannedIds,
       _fixedIncomeIds = fixedIncomeIds;

  /// 추가 수입.
  final List<Income> incomes;

  /// 고정 수입.
  final List<FixedIncome> fixedIncomes;
  final List<PlannedExpense> plannedExpenses;
  final List<ExtraExpense> extraExpenses;
  final List<CardBill> cardBills;

  /// 휴지통에 넣은 항목. 위 목록과 합계에는 들어가지 않는다.
  final List<TrashedEntry> trashed;

  /// 연결이 끊긴 채 더해 아직 서버에 올라가지 않은 항목 id. 상대에게는 아직 보이지 않는다.
  ///
  /// 연결되어 서버가 받으면 빠지고, 서버가 거부하면 항목째 목록에서 빠진다(`EntriesRepository.rejectedAdds`).
  /// 연결된 채 서버 응답을 기다리는 잠깐은 넣지 않아, 저장할 때마다 표시가 깜빡이지 않는다.
  final Set<String> unsentIds;
  final Set<String> _plannedIds;
  final Set<String> _fixedIncomeIds;

  /// 휴지통에 넣은 것까지 그달에 있는 고정 지출 문서 id. 반복 설정으로 채울 때 이미 있는 것을 건너뛰는 데 쓴다.
  ///
  /// 만들 때 넘긴 id에 [plannedExpenses]와 [trashed]의 고정 지출 id를 더한 것이다.
  Set<String> get plannedIds => {
    ..._plannedIds,
    for (final expense in plannedExpenses) expense.id,
    for (final item in trashed)
      if (item.entry case PlannedExpense(:final id)) id,
  };

  /// 휴지통에 넣은 것까지 그달에 있는 고정 수입 문서 id. [plannedIds]와 같은 일을 고정 수입에 한다.
  Set<String> get fixedIncomeIds => {
    ..._fixedIncomeIds,
    for (final income in fixedIncomes) income.id,
    for (final item in trashed)
      if (item.entry case FixedIncome(:final id)) id,
  };

  /// [kind](고정 지출·고정 수입) 반복 설정으로 만든 문서가 그달에 이미 있는 id.
  Set<String> fixedIdsOf(EntryKind kind) =>
      kind == EntryKind.fixedIncome ? fixedIncomeIds : plannedIds;
}
