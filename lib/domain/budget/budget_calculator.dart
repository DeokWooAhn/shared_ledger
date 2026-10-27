import '../model/category.dart';
import '../model/month_ledger.dart';
import '../model/payment_method.dart';
import 'budget_summary.dart';

/// 한 달 가계부 데이터로 [BudgetSummary]를 계산한다.
///
/// 규칙은 기존 구글 시트의 수식을 그대로 옮겼다. 시트와 숫자가 같은지는
/// `test/core/budget/sheet_golden_test.dart`가 확인한다.
class BudgetCalculator {
  BudgetCalculator({
    required Iterable<Category> categories,
    required Iterable<PaymentMethod> paymentMethods,
  }) : _categories = {for (final c in categories) c.id: c},
       _paymentMethods = {for (final m in paymentMethods) m.id: m};

  final Map<String, Category> _categories;
  final Map<String, PaymentMethod> _paymentMethods;

  BudgetSummary summarize(MonthLedger ledger) {
    var cashIn = 0;
    for (final income in ledger.incomes) {
      cashIn += income.amount;
    }

    var plannedTotal = 0;
    var cashOut = 0;
    var saving = 0;
    var cardUsage = 0;
    final byCategory = <String, int>{};
    final byMember = <String, int>{};
    final byCard = <String, int>{};

    for (final expense in ledger.plannedExpenses) {
      final amount = expense.amount ?? 0;
      plannedTotal += amount;
      _add(byCategory, expense.categoryId, amount);
      _add(byMember, expense.memberId, amount);
      if (_countsAsSaving(expense.categoryId)) {
        saving += amount;
      }
      if (_isCard(expense.paymentMethodId)) {
        // 카드는 지급일과 상관없이 다음 달 청구 예정으로 본다.
        cardUsage += amount;
        _add(byCard, expense.paymentMethodId, amount);
      } else if (expense.isPaid) {
        cashOut += amount;
      }
    }

    var extraTotal = 0;
    for (final expense in ledger.extraExpenses) {
      extraTotal += expense.amount;
      if (_isCard(expense.paymentMethodId)) {
        cardUsage += expense.amount;
        _add(byCard, expense.paymentMethodId, expense.amount);
      } else {
        cashOut += expense.amount;
      }
    }

    var cardBillTotal = 0;
    for (final bill in ledger.cardBills) {
      cardBillTotal += bill.amount;
    }
    cashOut += cardBillTotal;

    return BudgetSummary(
      cashIn: cashIn,
      spending: plannedTotal + extraTotal,
      cashOut: cashOut,
      saving: saving,
      cardUsage: cardUsage,
      cardBillTotal: cardBillTotal,
      plannedTotal: plannedTotal,
      plannedByCategory: byCategory,
      plannedByMember: byMember,
      cardUsageByCard: byCard,
    );
  }

  /// 찾을 수 없는 결제수단은 카드가 아닌 것으로 본다.
  bool _isCard(String paymentMethodId) =>
      _paymentMethods[paymentMethodId]?.kind == PaymentKind.card;

  /// 찾을 수 없는 분류는 저축으로 보지 않는다.
  bool _countsAsSaving(String categoryId) =>
      _categories[categoryId]?.countsAsSaving ?? false;

  static void _add(Map<String, int> totals, String key, int amount) {
    totals.update(key, (value) => value + amount, ifAbsent: () => amount);
  }
}
