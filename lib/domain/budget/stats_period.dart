import '../model/year_month.dart';

/// 통계 기간에 넣을 수 있는 가장 많은 달 수. 달마다 그달 항목을 읽어서 더 늘리지 않는다.
const statsMaxMonths = 12;

/// 통계 기간을 고르는 방법(은행 앱의 조회 기간처럼). 직접 고르기 말고는 이번 달로 끝나는 최근 몇 개월이다.
enum StatsRange {
  month1(1),
  month3(3),
  month6(6),
  year1(12),
  custom(null);

  const StatsRange(this.months);

  /// 최근 몇 개월인지. 직접 고르기는 null.
  final int? months;
}

/// 통계를 보는 기간. [from]부터 [to]까지(둘 다 넣는다) 최대 [statsMaxMonths]개월이다.
class StatsPeriod {
  const StatsPeriod._(this.range, this.from, this.to);

  /// [thisMonth]로 끝나는 최근 [range]. [range]가 직접 고르기면 이번 달 하나다.
  factory StatsPeriod.recent(StatsRange range, YearMonth thisMonth) =>
      StatsPeriod._(
        range,
        _monthAt(_indexOf(thisMonth) - (range.months ?? 1) + 1),
        thisMonth,
      );

  /// 직접 고른 기간. 끝 달이 시작 달보다 앞이면 둘을 바꾸고, [statsMaxMonths]개월을 넘으면 시작 달부터 그만큼만 센다.
  factory StatsPeriod.custom(YearMonth from, YearMonth to) {
    final (start, end) = from.compareTo(to) <= 0 ? (from, to) : (to, from);
    final last = _indexOf(start) + statsMaxMonths - 1;
    return StatsPeriod._(
      StatsRange.custom,
      start,
      _indexOf(end) > last ? _monthAt(last) : end,
    );
  }

  final StatsRange range;
  final YearMonth from;
  final YearMonth to;

  /// 시작 달을 [month]로 바꾼 직접 고른 기간. 끝 달이 시작 달보다 앞서거나 [statsMaxMonths]개월을 넘게 떨어지면 끝 달을 당긴다.
  StatsPeriod withFrom(YearMonth month) {
    final index = _indexOf(month);
    final end = _indexOf(to).clamp(index, index + statsMaxMonths - 1);
    return StatsPeriod._(StatsRange.custom, month, _monthAt(end));
  }

  /// 끝 달을 [month]로 바꾼 직접 고른 기간. 시작 달이 끝 달보다 뒤거나 [statsMaxMonths]개월을 넘게 떨어지면 시작 달을 당긴다.
  StatsPeriod withTo(YearMonth month) {
    final index = _indexOf(month);
    final start = _indexOf(from).clamp(index - statsMaxMonths + 1, index);
    return StatsPeriod._(StatsRange.custom, _monthAt(start), month);
  }

  /// 기간의 달 수.
  int get length => _indexOf(to) - _indexOf(from) + 1;

  /// 기간의 달. 오래된 달부터다.
  List<YearMonth> get months => [
    for (var index = _indexOf(from); index <= _indexOf(to); index++)
      _monthAt(index),
  ];

  /// [month]가 기간 안에 있는지.
  bool contains(YearMonth month) =>
      month.compareTo(from) >= 0 && month.compareTo(to) <= 0;

  @override
  bool operator ==(Object other) =>
      other is StatsPeriod &&
      other.range == range &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(range, from, to);

  // 달을 0년 1월부터 센 번호로 바꿔 더하고 뺀다.
  static int _indexOf(YearMonth month) => month.year * 12 + month.month - 1;

  static YearMonth _monthAt(int index) =>
      YearMonth(index ~/ 12, index % 12 + 1);
}
