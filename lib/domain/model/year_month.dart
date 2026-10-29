/// 가계부의 한 달(달력 1일~말일). Firestore 달 문서 id(`2026-10`)와 같다.
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month)
    : assert(month >= 1 && month <= 12, '월은 1~12');

  /// [date]가 속한 달.
  YearMonth.of(DateTime date) : this(date.year, date.month);

  static final _idPattern = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$');

  /// [id]처럼 생긴 달 문서 id(`2026-10`)를 읽는다. 모양이 다르면 null.
  static YearMonth? tryParse(String id) {
    if (_idPattern.firstMatch(id) case final match?) {
      return YearMonth(int.parse(match[1] ?? ''), int.parse(match[2] ?? ''));
    }
    return null;
  }

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

/// 오래된 것부터 정렬한 [months]에서 [from] 바로 앞의 달. 없으면 null.
YearMonth? monthBefore(List<YearMonth> months, YearMonth from) {
  for (final month in months.reversed) {
    if (month.compareTo(from) < 0) return month;
  }
  return null;
}

/// 오래된 것부터 정렬한 [months]에서 [from] 바로 뒤의 달. 없으면 null.
YearMonth? monthAfter(List<YearMonth> months, YearMonth from) {
  for (final month in months) {
    if (month.compareTo(from) > 0) return month;
  }
  return null;
}

/// [months] 가운데 [to]에 가장 가까운 달. [to]가 있으면 [to]이고, 거리가 같으면 앞의 달이다. 비었으면 null.
///
/// 앱을 켤 때 요약·항목 탭이 처음 볼 달을 고른다(이번 달 가계부가 없을 수 있다).
YearMonth? nearestMonth(Iterable<YearMonth> months, YearMonth to) {
  int distance(YearMonth month) =>
      ((month.year - to.year) * 12 + month.month - to.month).abs();
  YearMonth? best;
  for (final month in months) {
    if (best == null) {
      best = month;
      continue;
    }
    final (d, bestD) = (distance(month), distance(best));
    if (d < bestD || (d == bestD && month.compareTo(best) < 0)) best = month;
  }
  return best;
}
