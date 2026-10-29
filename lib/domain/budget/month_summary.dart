import '../model/category.dart';
import '../model/member.dart';
import '../model/month_ledger.dart';
import '../model/payment_method.dart';
import 'budget_calculator.dart';
import 'budget_summary.dart';

/// 분류 하나의 고정 지출 소계. [category]가 null이면 설정에서 지워진 분류에 남은 지출을 모은 것이다.
typedef CategoryTotal = ({Category? category, int amount});

/// 카드 하나의 이번 달 사용분.
typedef CardTotal = ({PaymentMethod card, int amount});

/// 월 요약 화면에 그릴 값. [BudgetSummary]에 분류·카드 이름과 화면에 필요한 건수를 붙인다.
class MonthSummary {
  const MonthSummary({
    required this.totals,
    required this.categories,
    required this.cards,
    required this.showsCards,
    required this.cardBillCount,
    required this.unpricedPlannedCount,
    required this.isEmpty,
  });

  /// 한 달 가계부와 설정으로 요약을 만든다. 계산은 [BudgetCalculator]가 한다.
  factory MonthSummary.of(
    MonthLedger ledger, {
    required List<Category> categories,
    required List<PaymentMethod> paymentMethods,
  }) {
    final totals = BudgetCalculator(
      categories: categories,
      paymentMethods: paymentMethods,
    ).summarize(ledger);
    final byCategory = totals.plannedByCategory;
    final known = {for (final category in categories) category.id};
    final orphans = [
      for (final MapEntry(:key, :value) in byCategory.entries)
        if (!known.contains(key)) value,
    ];
    final byCard = totals.cardUsageByCard;
    return MonthSummary(
      totals: totals,
      categories: [
        for (final category in categories)
          // 숨긴 분류는 그달에 쓴 항목이 있을 때만 보인다.
          if (!category.hidden || byCategory.containsKey(category.id))
            (category: category, amount: byCategory[category.id] ?? 0),
        if (orphans.isNotEmpty)
          (category: null, amount: orphans.fold(0, (sum, v) => sum + v)),
      ],
      cards: [
        for (final method in paymentMethods)
          if (byCard[method.id] case final amount? when amount > 0)
            (card: method, amount: amount),
      ],
      showsCards:
          paymentMethods.any((m) => m.kind == PaymentKind.card && !m.hidden) ||
          byCard.isNotEmpty ||
          ledger.cardBills.isNotEmpty,
      cardBillCount: ledger.cardBills.length,
      unpricedPlannedCount: ledger.plannedExpenses
          .where((e) => e.amount == null)
          .length,
      isEmpty:
          ledger.incomes.isEmpty &&
          ledger.plannedExpenses.isEmpty &&
          ledger.extraExpenses.isEmpty &&
          ledger.cardBills.isEmpty,
    );
  }

  /// 시트와 같은 계산 결과(남는 현금, 현금 유입·유출, 이번 달 지출, 저축, 카드, 소계).
  final BudgetSummary totals;

  /// 고정 지출의 분류별 소계. 설정의 분류 순서대로 모두 넣고(0원 포함),
  /// 지워진 분류에 남은 지출이 있으면 맨 뒤에 하나로 모은다. 숨긴 분류는 그달에 쓴 항목이 있을 때만 넣는다.
  final List<CategoryTotal> categories;

  /// 이번 달 카드 사용분의 카드별 소계. 쓴 카드만, 결제수단 순서대로.
  final List<CardTotal> cards;

  /// 카드 영역을 보여줄지. 숨기지 않은 카드도, 그달 카드 사용분·카드 대금도 없으면 숨긴다.
  final bool showsCards;

  /// 그달 카드 대금 건수(저번 달 사용분).
  final int cardBillCount;

  /// 금액이 아직 정해지지 않은 고정 지출 건수. 합계에서는 0원으로 친다.
  final int unpricedPlannedCount;

  /// 그달에 휴지통 밖의 항목이 하나도 없는지.
  final bool isEmpty;

  /// [slot] 사람의 고정 지출 소계.
  int plannedOf(MemberSlot slot) => totals.plannedByMember[slot.name] ?? 0;
}
