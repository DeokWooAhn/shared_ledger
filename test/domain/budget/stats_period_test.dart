import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/budget/stats_period.dart';
import 'package:shared_ledger/domain/model/year_month.dart';

const november = YearMonth(2026, 11);

void main() {
  test('최근 몇 개월은 이번 달로 끝나고, 해를 넘겨 센다', () {
    final half = StatsPeriod.recent(StatsRange.month6, november);
    expect((half.from, half.to), (const YearMonth(2026, 6), november));
    expect(half.length, 6);

    final year = StatsPeriod.recent(StatsRange.year1, november);
    expect(year.from, const YearMonth(2025, 12));
    expect(year.months, hasLength(12));
    expect(year.months.first, const YearMonth(2025, 12));

    final one = StatsPeriod.recent(StatsRange.month1, november);
    expect((one.from, one.to), (november, november));
  });

  test('직접 고른 기간은 앞뒤가 바뀌면 바로잡고, 12개월이 넘으면 시작 달부터 12개월만 센다', () {
    final swapped = StatsPeriod.custom(november, const YearMonth(2026, 3));
    expect((swapped.from, swapped.to), (const YearMonth(2026, 3), november));
    expect(swapped.range, StatsRange.custom);

    final long = StatsPeriod.custom(
      const YearMonth(2025, 1),
      const YearMonth(2026, 11),
    );
    expect(
      (long.from, long.to),
      (const YearMonth(2025, 1), const YearMonth(2025, 12)),
    );
  });

  test('한쪽 끝을 휠로 옮기면 다른 쪽 끝을 순서와 12개월에 맞게 당긴다', () {
    final period = StatsPeriod.custom(
      const YearMonth(2026, 6),
      const YearMonth(2026, 9),
    );

    // 시작을 끝보다 뒤로 옮기면 끝도 따라온다.
    expect(period.withFrom(november).to, november);
    // 시작을 1년 넘게 앞으로 옮기면 끝을 12개월 안으로 당긴다.
    expect(
      period.withFrom(const YearMonth(2025, 1)).to,
      const YearMonth(2025, 12),
    );
    // 끝을 시작보다 앞으로 옮기면 시작도 따라간다.
    expect(
      period.withTo(const YearMonth(2026, 2)).from,
      const YearMonth(2026, 2),
    );
    // 끝을 1년 넘게 뒤로 옮기면 시작을 당긴다.
    expect(
      period.withTo(const YearMonth(2027, 9)).from,
      const YearMonth(2026, 10),
    );
  });

  test('기간 안의 달인지 알고, 같은 기간끼리는 같다', () {
    final period = StatsPeriod.recent(StatsRange.month3, november);

    expect(period.contains(const YearMonth(2026, 9)), isTrue);
    expect(period.contains(const YearMonth(2026, 8)), isFalse);
    expect(period.contains(const YearMonth(2026, 12)), isFalse);
    expect(period, StatsPeriod.recent(StatsRange.month3, november));
    expect(
      period,
      isNot(StatsPeriod.custom(const YearMonth(2026, 9), november)),
    );
  });
}
