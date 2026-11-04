import '../../budget/statistics.dart';
import '../../budget/stats_period.dart';
import '../../model/category.dart';
import '../../model/month_ledger.dart';
import '../../model/payment_method.dart';
import '../../model/year_month.dart';

/// 고른 기간 안의 가계부 달로 통계를 계산한다. 계산 규칙은 [Statistics.of](`docs/plan.md`의 '계산 규칙').
class CalculateStatisticsUseCase {
  const CalculateStatisticsUseCase();

  Statistics call(
    Map<YearMonth, MonthLedger> ledgers, {
    required StatsPeriod period,
    required List<Category> categories,
    required List<PaymentMethod> paymentMethods,
  }) => Statistics.of(
    ledgers,
    period: period,
    categories: categories,
    paymentMethods: paymentMethods,
  );
}
