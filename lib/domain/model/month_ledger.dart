import 'ledger_entries.dart';
import 'trashed_entry.dart';

/// 한 달치 가계부 데이터.
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
