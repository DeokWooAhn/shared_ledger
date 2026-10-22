/// 가계부의 한 달(달력 1일~말일). Firestore 달 문서 id(`2026-10`)와 같다.
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month)
    : assert(month >= 1 && month <= 12, '월은 1~12');

  /// [date]가 속한 달.
  YearMonth.of(DateTime date) : this(date.year, date.month);

  final int year;
  final int month;

  /// Firestore 달 문서 id. `firestore.rules`의 validMonth 형식(`yyyy-MM`)과 같다.
  String get id =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  YearMonth get next =>
      month == 12 ? YearMonth(year + 1, 1) : YearMonth(year, month + 1);

  YearMonth get previous =>
      month == 1 ? YearMonth(year - 1, 12) : YearMonth(year, month - 1);

  @override
  int compareTo(YearMonth other) => year != other.year
      ? year.compareTo(other.year)
      : month.compareTo(other.month);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => id;
}
