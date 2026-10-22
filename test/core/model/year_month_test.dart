import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/year_month.dart';

void main() {
  test('문서 id는 yyyy-MM 형식이다', () {
    expect(const YearMonth(2026, 3).id, '2026-03');
    expect(const YearMonth(2026, 10).id, '2026-10');
  });

  test('날짜가 속한 달은 달력 1일~말일 기준이다', () {
    expect(YearMonth.of(DateTime(2026, 10, 1)), const YearMonth(2026, 10));
    expect(
      YearMonth.of(DateTime(2026, 10, 31, 23, 59)),
      const YearMonth(2026, 10),
    );
  });

  test('다음 달·이전 달은 해를 넘어간다', () {
    expect(const YearMonth(2026, 12).next, const YearMonth(2027, 1));
    expect(const YearMonth(2027, 1).previous, const YearMonth(2026, 12));
    expect(const YearMonth(2026, 10).next, const YearMonth(2026, 11));
  });

  test('앞선 달이 작다', () {
    expect(
      const YearMonth(2026, 12).compareTo(const YearMonth(2027, 1)),
      lessThan(0),
    );
    expect(const YearMonth(2026, 10).compareTo(const YearMonth(2026, 10)), 0);
  });
}
