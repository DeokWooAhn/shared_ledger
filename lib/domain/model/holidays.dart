/// 한 해의 공휴일(대체·임시공휴일, 선거일 포함). 달력이 날짜를 빨간색으로 칠하고 이름을 알리는 데 쓴다.
///
/// 공공데이터포털 '한국천문연구원_특일 정보'를 Cloud Functions(`functions/src/index.ts`의 syncHolidays)가
/// 매일 받아 `holidays/{연도}`에 둔 것이다. 아직 받지 못한 해는 비어 있고, 그때는 일요일만 빨갛다.
class Holidays {
  /// [days]는 `2026-10-03` 같은 날짜에서 공휴일 이름으로 가는 표다.
  const Holidays([this.days = const {}]);

  final Map<String, String> days;

  bool get isEmpty => days.isEmpty;

  /// [date]가 공휴일이면 그 이름, 아니면 null. 시각은 보지 않는다.
  String? nameOf(DateTime date) => days[holidayKey(date)];

  @override
  bool operator ==(Object other) =>
      other is Holidays &&
      other.days.length == days.length &&
      days.entries.every((entry) => other.days[entry.key] == entry.value);

  @override
  int get hashCode => Object.hashAllUnordered(
    days.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}

/// 공휴일 표의 날짜 키. 예: '2026-10-03'
String holidayKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
