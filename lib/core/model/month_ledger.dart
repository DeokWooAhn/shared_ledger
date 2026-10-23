import 'ledger_entries.dart';
import 'trashed_entry.dart';

/// 한 달치 가계부 데이터.
class MonthLedger {
  const MonthLedger({
    this.incomes = const [],
    this.plannedExpenses = const [],
    this.extraExpenses = const [],
    this.cardBills = const [],
    this.trashed = const [],
    Set<String> plannedIds = const {},
  }) : _plannedIds = plannedIds;

  final List<Income> incomes;
  final List<PlannedExpense> plannedExpenses;
  final List<ExtraExpense> extraExpenses;
  final List<CardBill> cardBills;

  /// 휴지통에 넣은 항목. 위 목록과 합계에는 들어가지 않는다.
  final List<TrashedEntry> trashed;
  final Set<String> _plannedIds;

  /// 휴지통에 넣은 것까지 그달에 있는 기본 월 지출 문서 id. 고정 지출로 채울 때 이미 있는 것을 건너뛰는 데 쓴다.
  ///
  /// 만들 때 넘긴 id에 [plannedExpenses]와 [trashed]의 기본 월 지출 id를 더한 것이다.
  Set<String> get plannedIds => {
    ..._plannedIds,
    for (final expense in plannedExpenses) expense.id,
    for (final item in trashed)
      if (item.entry case PlannedExpense(:final id)) id,
  };
}
