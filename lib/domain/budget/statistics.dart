import '../model/category.dart';
import '../model/member.dart';
import '../model/month_ledger.dart';
import '../model/payment_method.dart';
import '../model/year_month.dart';
import 'budget_summary.dart';
import 'month_summary.dart';
import 'stats_period.dart';

/// 한 달에 모은 돈. 빠져나간 저축 + 남는 현금이다([BudgetSummary.saved]).
class MonthSaved {
  const MonthSaved({
    required this.month,
    required this.saving,
    required this.cash,
  });

  final YearMonth month;

  /// 빠져나간 저축(지급 완료했거나 카드로 낸 것).
  final int saving;

  /// 남는 현금. 음수일 수 있다.
  final int cash;

  /// 그달에 모은 돈. 음수일 수 있다.
  int get total => saving + cash;
}

/// 결제수단 하나의 기간 지출. [method]가 null이면 설정에서 지워진 결제수단에 남은 지출을 모은 것이다.
typedef PaymentTotal = ({PaymentMethod? method, int amount});

/// 통계 탭에 그릴 값. 고른 기간에 가계부가 있는 달을 모두 더한다.
class Statistics {
  const Statistics({
    required this.period,
    required this.savedMonths,
    required this.income,
    required this.spending,
    required this.saving,
    required this.categories,
    required this.plannedByMember,
    required this.payments,
  });

  /// 기간 [period] 안의 달 가계부 [ledgers]로 통계를 만든다. 기간 밖의 달은 넣지 않는다.
  /// 분류·결제수단은 지금 설정으로 지난 달도 계산한다(월 요약과 같다).
  factory Statistics.of(
    Map<YearMonth, MonthLedger> ledgers, {
    required StatsPeriod period,
    required List<Category> categories,
    required List<PaymentMethod> paymentMethods,
  }) {
    final months = [
      for (final month in ledgers.keys)
        if (period.contains(month)) month,
    ]..sort((a, b) => a.compareTo(b));
    final saved = <MonthSaved>[];
    var income = 0;
    var spending = 0;
    var saving = 0;
    // 분류 id(지워진 분류는 null) → 합계. 설정 순서를 지키려고 처음 나온 순서대로 둔다.
    final byCategory = <String?, CategoryTotal>{};
    final byMember = {for (final slot in MemberSlot.values) slot: 0};
    final bySpending = <String, int>{};
    for (final month in months) {
      final summary = MonthSummary.of(
        ledgers[month]!,
        categories: categories,
        paymentMethods: paymentMethods,
      );
      final totals = summary.totals;
      saved.add(
        MonthSaved(
          month: month,
          saving: totals.paidSaving,
          cash: totals.remainingCash,
        ),
      );
      income += totals.cashIn;
      spending += totals.spending;
      saving += totals.saving;
      for (final (:category, :amount) in summary.categories) {
        final before = byCategory[category?.id]?.amount ?? 0;
        byCategory[category?.id] = (
          category: category,
          amount: before + amount,
        );
      }
      for (final slot in MemberSlot.values) {
        byMember[slot] = byMember[slot]! + summary.plannedOf(slot);
      }
      for (final MapEntry(:key, :value)
          in totals.spendingByPaymentMethod.entries) {
        bySpending[key] = (bySpending[key] ?? 0) + value;
      }
    }
    final known = {for (final method in paymentMethods) method.id};
    final orphans = bySpending.entries
        .where((entry) => !known.contains(entry.key))
        .fold(0, (sum, entry) => sum + entry.value);
    return Statistics(
      period: period,
      // 밖에서 고칠 수 없게 한다.
      savedMonths: List.unmodifiable(saved),
      income: income,
      spending: spending,
      saving: saving,
      categories: List.unmodifiable([
        for (final total in byCategory.values)
          if (total.category != null && total.amount > 0) total,
        if (byCategory[null] case final orphan? when orphan.amount > 0) orphan,
      ]),
      plannedByMember: Map.unmodifiable(byMember),
      payments: List.unmodifiable([
        for (final method in paymentMethods)
          if (bySpending[method.id] case final amount? when amount > 0)
            (method: method, amount: amount),
        if (orphans > 0) (method: null, amount: orphans),
      ]),
    );
  }

  /// 고른 기간.
  final StatsPeriod period;

  /// 기간 안에 가계부가 있는 달마다 모은 돈. 오래된 달부터다.
  final List<MonthSaved> savedMonths;

  /// 기간의 수입 합계(현금 유입: 추가 수입 + 받음 완료인 고정 수입).
  final int income;

  /// 기간의 지출 합계(고정 지출 + 추가 지출). 저축 분류의 고정 지출도 들어 있다.
  final int spending;

  /// 기간의 저축 합계(저축으로 집계하는 분류의 고정 지출, 지급 여부와 상관없이). [spending]에 들어 있다.
  final int saving;

  /// 고정 지출의 분류별 합계. 쓴 분류만 설정 순서대로, 지워진 분류에 남은 지출은 맨 뒤에 하나로 모은다.
  final List<CategoryTotal> categories;

  /// 고정 지출의 구성원별 합계.
  final Map<MemberSlot, int> plannedByMember;

  /// 기간 지출의 결제수단별 합계. 쓴 결제수단만 설정 순서대로, 지워진 결제수단의 지출은 맨 뒤에 하나로 모은다.
  final List<PaymentTotal> payments;

  /// 기간에 모은 돈의 합계.
  int get saved => savedMonths.fold(0, (sum, m) => sum + m.total);

  /// 기간에 빠져나간 저축의 합계.
  int get savedSaving => savedMonths.fold(0, (sum, m) => sum + m.saving);

  /// 기간에 남는 현금의 합계.
  int get savedCash => savedMonths.fold(0, (sum, m) => sum + m.cash);

  /// 고정 지출 합계.
  int get planned => categories.fold(0, (sum, c) => sum + c.amount);

  /// 추가 지출 합계(지출 − 고정 지출).
  int get extra => spending - planned;

  /// 저축을 뺀 지출(쓴 돈). 수입 대비 비율에서 저축과 나눠 보인다.
  int get consumption => spending - saving;

  /// 수입에서 지출(저축 포함)을 뺀 남은 돈. 지출이 수입보다 많으면 음수다.
  int get left => income - spending;

  /// [slot] 사람의 고정 지출 합계.
  int plannedOf(MemberSlot slot) => plannedByMember[slot] ?? 0;
}
