import '../../domain/model/ledger_entries.dart';
import '../../domain/model/month_ledger.dart';
import '../../domain/model/year_month.dart';
import '../../domain/format/won.dart';

/// 달력 한 칸(하루)에 모인 항목. 목록은 읽기 전용으로 감싸서, 받은 쪽이 고쳐 달력 데이터를 바꿀 수 없다.
class CalendarDay {
  CalendarDay({
    required this.date,
    List<LedgerEntry> entries = const [],
    List<PlannedExpense> scheduled = const [],
  }) : entries = List.unmodifiable(entries),
       scheduled = List.unmodifiable(scheduled);

  final DateTime date;

  /// 그날 받은·지급한·쓴·출금한 항목. 수입, 기본 월 지출, 추가지출, 카드대금 순이고 같은 종류는 제목 순이다.
  final List<LedgerEntry> entries;

  /// 그날이 예정일인 지급 전 기본 월 지출. 제목 순이다.
  final List<PlannedExpense> scheduled;

  /// 들어온 돈(수입) 합계.
  int get income => _sum(entries.whereType<Income>());

  /// 나간 돈(기본 월 지출·추가지출·카드대금) 합계. 금액 미정은 0원으로 친다.
  int get spending => _sum(entries.where((e) => e is! Income));

  /// 그날 합계. 들어온 돈에서 나간 돈을 뺀다.
  int get net => income - spending;

  /// 예정 금액 합계. 금액 미정은 0원으로 친다.
  int get scheduledTotal => _sum(scheduled);

  bool get isEmpty => entries.isEmpty && scheduled.isEmpty;
}

/// 한 달 달력. 날짜가 있는 항목은 그 날짜에, 지급 전 기본 월 지출은 예정일에 놓는다.
///
/// 날짜가 없는 항목(받은 날 없는 수입, 쓴 날 없는 추가지출, 출금일 없는 카드대금, 예정일도 없는 기본 월 지출)과
/// 그달 밖의 날짜로 잘못 저장된 항목은 달력에 놓지 않고 [undatedCount]로만 센다.
class CalendarMonth {
  CalendarMonth._(this.month, this._days, this.undatedCount);

  factory CalendarMonth.of(MonthLedger ledger, YearMonth month) {
    final entries = <int, List<LedgerEntry>>{};
    final scheduled = <int, List<PlannedExpense>>{};
    var undated = 0;
    int? dayIn(DateTime? date) =>
        date != null && YearMonth.of(date) == month ? date.day : null;

    for (final LedgerEntry entry in [
      ...ledger.incomes,
      ...ledger.plannedExpenses,
      ...ledger.extraExpenses,
      ...ledger.cardBills,
    ]) {
      if (dayIn(entry.date) case final day?) {
        (entries[day] ??= []).add(entry);
        continue;
      }
      if (entry case PlannedExpense(isPaid: false, :final dueOn)) {
        if (dayIn(dueOn) case final day?) {
          (scheduled[day] ??= []).add(entry);
          continue;
        }
      }
      undated++;
    }

    final days = <int, CalendarDay>{
      for (final day in {...entries.keys, ...scheduled.keys})
        day: CalendarDay(
          date: DateTime(month.year, month.month, day),
          entries: (entries[day] ?? [])..sort(_byKindThenTitle),
          scheduled: (scheduled[day] ?? [])
            ..sort((a, b) => a.title.compareTo(b.title)),
        ),
    };
    return CalendarMonth._(month, days, undated);
  }

  final YearMonth month;
  final Map<int, CalendarDay> _days;

  /// 달력에 놓지 못한 항목 수.
  final int undatedCount;

  /// 그달의 날 수(28~31).
  int get length => DateTime(month.year, month.month + 1, 0).day;

  /// 그달 [day]일. 항목이 없는 날이면 빈 칸이다.
  CalendarDay dayOf(int day) =>
      _days[day] ?? CalendarDay(date: DateTime(month.year, month.month, day));
}

/// 달력 칸에 들어가는 짧은 금액. 부호를 붙이고, 1만 원 이상은 만 원 단위로 소수 한 자리까지 쓴다.
/// 예: `+270만`, `-25.8만`, `-9,800`
String calendarAmount(int amount) {
  final sign = amount > 0
      ? '+'
      : amount < 0
      ? '-'
      : '';
  final abs = amount.abs();
  if (abs < 10000) return '$sign${wonDigits(abs)}';
  // 천 원 단위에서 반올림한 '만 원의 십분의 일' 수.
  final tenths = (abs + 500) ~/ 1000;
  final (whole, fraction) = (tenths ~/ 10, tenths % 10);
  return '$sign${wonDigits(whole)}${fraction == 0 ? '' : '.$fraction'}만';
}

int _sum(Iterable<LedgerEntry> entries) =>
    entries.fold(0, (sum, e) => sum + (e.amount ?? 0));

int _byKindThenTitle(LedgerEntry a, LedgerEntry b) {
  final byKind = a.kind.index.compareTo(b.kind.index);
  return byKind != 0 ? byKind : _titleOf(a).compareTo(_titleOf(b));
}

// 카드대금은 제목이 없어 카드 id로 줄 세운다(화면에는 카드 이름이 보인다).
String _titleOf(LedgerEntry entry) => switch (entry) {
  Income(:final title) ||
  PlannedExpense(:final title) ||
  ExtraExpense(:final title) => title,
  CardBill(:final cardId) => cardId,
};
