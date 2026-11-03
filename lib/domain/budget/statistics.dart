import '../model/category.dart';
import '../model/month_ledger.dart';
import '../model/payment_method.dart';
import '../model/year_month.dart';
import 'budget_calculator.dart';
import 'budget_summary.dart';
import 'month_summary.dart';

/// 달마다 모은 돈 막대에 넣는 달 수.
const statisticsRecentMonths = 6;

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

/// 결제수단 하나의 그달 지출. [method]가 null이면 설정에서 지워진 결제수단에 남은 지출을 모은 것이다.
typedef PaymentTotal = ({PaymentMethod? method, int amount});

/// 통계 탭에 그릴 값. 보고 있는 달의 요약에, 그달까지 모은 돈과 지난달 지출, 결제수단별 지출을 붙인다.
class Statistics {
  const Statistics({
    required this.month,
    required this.summary,
    required this.savedMonths,
    required this.payments,
    this.previous,
  });

  /// [month]의 가계부 [ledger]와, 그달까지 가계부가 있는 모든 달 [history]로 통계를 만든다.
  ///
  /// [history]는 달 목록을 아직 모으지 않은 옛 가계부면 null이고, 그때는 모은 돈과 지난달 지출을 알 수 없다.
  /// 분류·결제수단은 지금 설정으로 지난 달도 계산한다(월 요약과 같다).
  factory Statistics.of(
    MonthLedger ledger, {
    required YearMonth month,
    required Map<YearMonth, MonthLedger>? history,
    required List<Category> categories,
    required List<PaymentMethod> paymentMethods,
  }) {
    final summary = MonthSummary.of(
      ledger,
      categories: categories,
      paymentMethods: paymentMethods,
    );
    final calculator = BudgetCalculator(
      categories: categories,
      paymentMethods: paymentMethods,
    );
    List<MonthSaved>? saved;
    ({YearMonth month, int spending})? previous;
    if (history != null) {
      final earlier = [
        for (final MapEntry(:key, :value) in history.entries)
          if (key.compareTo(month) < 0)
            (month: key, totals: calculator.summarize(value)),
      ]..sort((a, b) => a.month.compareTo(b.month));
      saved = [
        for (final (:month, :totals) in earlier) _saved(month, totals),
        _saved(month, summary.totals),
      ];
      if (earlier.lastOrNull case (:final month, :final totals)?) {
        previous = (month: month, spending: totals.spending);
      }
    }
    final bySpending = summary.totals.spendingByPaymentMethod;
    final known = {for (final method in paymentMethods) method.id};
    final orphans = bySpending.entries
        .where((entry) => !known.contains(entry.key))
        .fold(0, (sum, entry) => sum + entry.value);
    return Statistics(
      month: month,
      summary: summary,
      savedMonths: saved,
      previous: previous,
      payments: [
        for (final method in paymentMethods)
          if (bySpending[method.id] case final amount? when amount > 0)
            (method: method, amount: amount),
        if (orphans > 0) (method: null, amount: orphans),
      ],
    );
  }

  static MonthSaved _saved(YearMonth month, BudgetSummary totals) => MonthSaved(
    month: month,
    saving: totals.paidSaving,
    cash: totals.remainingCash,
  );

  /// 보고 있는 달.
  final YearMonth month;

  /// 보고 있는 달의 요약(그달 지출, 고정 지출 분류별·구성원별).
  final MonthSummary summary;

  /// 그달까지 가계부가 있는 모든 달의 모은 돈. 오래된 달부터다. 달 목록을 모르는 옛 가계부면 null.
  final List<MonthSaved>? savedMonths;

  /// 그달 바로 앞의 가계부 달과 그달 지출. 앞의 달이 없거나 달 목록을 모르면 null.
  final ({YearMonth month, int spending})? previous;

  /// 그달 지출의 결제수단별 소계. 쓴 결제수단만 설정 순서대로, 지워진 결제수단의 지출은 맨 뒤에 하나로 모은다.
  final List<PaymentTotal> payments;

  /// 그달까지 모은 돈의 합계. 달 목록을 모르면 null.
  int? get saved => savedMonths?.fold<int>(0, (sum, m) => sum + m.total);

  /// 그달까지 빠져나간 저축의 합계. 달 목록을 모르면 null.
  int? get savedSaving => savedMonths?.fold<int>(0, (sum, m) => sum + m.saving);

  /// 그달까지 남는 현금의 합계. 달 목록을 모르면 null.
  int? get savedCash => savedMonths?.fold<int>(0, (sum, m) => sum + m.cash);

  /// 달마다 모은 돈 막대에 넣을 달. 그달까지 최근 [statisticsRecentMonths]개 달이다.
  List<MonthSaved> get recentSaved {
    final all = savedMonths ?? const <MonthSaved>[];
    return all.length <= statisticsRecentMonths
        ? all
        : all.sublist(all.length - statisticsRecentMonths);
  }
}
