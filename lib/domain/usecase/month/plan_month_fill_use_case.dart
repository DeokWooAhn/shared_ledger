import '../../model/expense_template.dart';
import '../../model/ledger.dart';
import '../../model/month_ledger.dart';
import '../../model/year_month.dart';

/// 보고 있는 달에 고정 지출로 채울 것.
class PlannedFill {
  const PlannedFill({
    required this.ledgerId,
    required this.month,
    required this.templates,
    this.recordMonth = false,
  });

  final String ledgerId;
  final YearMonth month;

  /// 그달에 아직 기본 월 지출이 없는 고정 지출.
  final List<ExpenseTemplate> templates;

  /// 채우면서 가계부의 항목 있는 달 목록에 그달을 더할지([Ledger.needsToRecord]).
  final bool recordMonth;

  @override
  bool operator ==(Object other) =>
      other is PlannedFill &&
      other.ledgerId == ledgerId &&
      other.month == month &&
      _sameTemplates(other.templates, templates) &&
      other.recordMonth == recordMonth;

  @override
  int get hashCode =>
      Object.hash(ledgerId, month, Object.hashAll(templates), recordMonth);

  static bool _sameTemplates(List<ExpenseTemplate> a, List<ExpenseTemplate> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 보고 있는 [month]에 고정 지출로 채울 것을 정한다. 채울 것이 없거나 채울 수 없으면 null.
///
/// 보기 전용이면(규칙이 막는다), 자동으로 채우지 않는 달이면(지난 달·다음 달보다 먼 달, [fillsFromTemplates]),
/// 요약·항목 탭이 오가지 않는 달이면([ledgerMonths]에 없는 달. 달력으로 지나가는 다음 달 등은 달력에서 가계부를 만들 때 채운다),
/// 그달 항목이나 고정 지출을 아직 받지 못했으면 null이다.
///
/// 그달 항목([entries])과 고정 지출([templates])은 앞의 조건을 지난 뒤에만 꺼낸다. 공급자가 그때만 구독하게 하려는 것이다.
class PlanMonthFillUseCase {
  const PlanMonthFillUseCase(this._now);

  final DateTime Function() _now;

  PlannedFill? call({
    required Ledger? ledger,
    required bool canWrite,
    required YearMonth month,
    required List<YearMonth>? ledgerMonths,
    required MonthLedger? Function() entries,
    required List<ExpenseTemplate>? Function() templates,
  }) {
    if (!canWrite || ledger == null) return null;
    if (!fillsFromTemplates(month, thisMonth: YearMonth.of(_now()))) {
      return null;
    }
    // 보기만 해서 그달이 생기지 않게 한다. 목록을 아직 모으지 않은 가계부(null)는 예전처럼 채운다.
    if (ledgerMonths != null && !ledgerMonths.contains(month)) return null;
    // 둘 다 꺼내야 둘 다 구독한다.
    final (got, all) = (entries(), templates());
    if (got == null || all == null) return null;
    final missing = templatesMissingIn(got, all);
    if (missing.isEmpty) return null;
    return PlannedFill(
      ledgerId: ledger.id,
      month: month,
      templates: missing,
      recordMonth: ledger.needsToRecord(month),
    );
  }
}
