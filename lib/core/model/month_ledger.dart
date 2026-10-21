import 'ledger_entries.dart';

/// 한 달치 가계부 데이터.
class MonthLedger {
  const MonthLedger({
    this.incomes = const [],
    this.plannedExpenses = const [],
    this.extraExpenses = const [],
    this.cardBills = const [],
  });

  final List<Income> incomes;
  final List<PlannedExpense> plannedExpenses;
  final List<ExtraExpense> extraExpenses;
  final List<CardBill> cardBills;
}
