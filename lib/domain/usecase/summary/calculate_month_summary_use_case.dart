import '../../budget/month_summary.dart';
import '../../model/category.dart';
import '../../model/month_ledger.dart';
import '../../model/payment_method.dart';

/// 그달 항목(휴지통 제외)과 분류·결제수단으로 월 요약을 계산한다. 계산 규칙은 [MonthSummary.of](`docs/plan.md`의 '계산 규칙').
class CalculateMonthSummaryUseCase {
  const CalculateMonthSummaryUseCase();

  MonthSummary call(
    MonthLedger ledger, {
    required List<Category> categories,
    required List<PaymentMethod> paymentMethods,
  }) => MonthSummary.of(
    ledger,
    categories: categories,
    paymentMethods: paymentMethods,
  );
}
