import '../../budget/statistics.dart';
import '../../model/category.dart';
import '../../model/month_ledger.dart';
import '../../model/payment_method.dart';
import '../../model/year_month.dart';

/// 보고 있는 달과 그달까지의 가계부 달로 통계를 계산한다. 계산 규칙은 [Statistics.of](`docs/plan.md`의 '계산 규칙').
class CalculateStatisticsUseCase {
  const CalculateStatisticsUseCase();

  Statistics call(
    MonthLedger ledger, {
    required YearMonth month,
    required Map<YearMonth, MonthLedger>? history,
    required List<Category> categories,
    required List<PaymentMethod> paymentMethods,
  }) => Statistics.of(
    ledger,
    month: month,
    history: history,
    categories: categories,
    paymentMethods: paymentMethods,
  );
}
