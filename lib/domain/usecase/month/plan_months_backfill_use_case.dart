import '../../model/ledger.dart';
import '../../model/year_month.dart';

/// 항목 있는 달을 찾는 범위. 가계부를 만든 달 [monthsBackfillSpan]달 전부터 이번 달 [monthsBackfillSpan]달 뒤까지다.
const monthsBackfillSpan = 12;

/// 항목 있는 달 목록을 처음 모을 가계부와 살펴볼 달.
class MonthsBackfill {
  const MonthsBackfill({required this.ledgerId, required this.months});

  final String ledgerId;

  /// 살펴볼 달. 오래된 것부터.
  final List<YearMonth> months;

  @override
  bool operator ==(Object other) =>
      other is MonthsBackfill &&
      other.ledgerId == ledgerId &&
      _sameMonths(other.months, months);

  @override
  int get hashCode => Object.hash(ledgerId, Object.hashAll(months));

  static bool _sameMonths(List<YearMonth> a, List<YearMonth> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// [createdIn](가계부를 만든 달) [monthsBackfillSpan]달 전부터 [thisMonth] [monthsBackfillSpan]달 뒤까지의 달.
List<YearMonth> monthsToBackfill({
  required YearMonth createdIn,
  required YearMonth thisMonth,
}) {
  var month = createdIn;
  for (var i = 0; i < monthsBackfillSpan; i++) {
    month = month.previous;
  }
  var last = thisMonth;
  for (var i = 0; i < monthsBackfillSpan; i++) {
    last = last.next;
  }
  return [for (; month.compareTo(last) <= 0; month = month.next) month];
}

/// [ledger]의 항목 있는 달 목록을 모아야 하면 그 범위를 정한다. 아니면 null.
///
/// 목록이 생기기 전에 만든 가계부([Ledger.months]가 null)이고 쓰기 권한이 있을 때만이다(보기 전용은 규칙이 막는다).
class PlanMonthsBackfillUseCase {
  const PlanMonthsBackfillUseCase(this._now);

  final DateTime Function() _now;

  MonthsBackfill? call({required Ledger? ledger, required bool canWrite}) {
    if (!canWrite || ledger == null || ledger.months != null) return null;
    final now = _now();
    return MonthsBackfill(
      ledgerId: ledger.id,
      months: monthsToBackfill(
        createdIn: YearMonth.of(ledger.createdAt ?? now),
        thisMonth: YearMonth.of(now),
      ),
    );
  }
}
