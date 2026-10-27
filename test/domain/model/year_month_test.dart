import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/year_month.dart';

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

  test('달 문서 id를 읽고, 모양이 다르면 null이다', () {
    expect(YearMonth.tryParse('2026-10'), const YearMonth(2026, 10));
    expect(YearMonth.tryParse('0999-01'), const YearMonth(999, 1));
    for (final id in ['2026-13', '2026-00', '2026-1', '26-10', '2026/10', '']) {
      expect(YearMonth.tryParse(id), isNull, reason: id);
    }
  });

  group('목록에서 앞뒤 달', () {
    const months = [
      YearMonth(2026, 3),
      YearMonth(2026, 8),
      YearMonth(2026, 10),
      YearMonth(2026, 11),
    ];

    test('사이의 빈 달은 건너뛰고 바로 앞뒤에 있는 달을 고른다', () {
      expect(monthBefore(months, const YearMonth(2026, 10)), months[1]);
      expect(monthAfter(months, const YearMonth(2026, 3)), months[1]);
      // 목록에 없는 달에서도 앞뒤 달을 찾는다(달력으로 빈 달에 간 뒤).
      expect(monthBefore(months, const YearMonth(2026, 9)), months[1]);
      expect(monthAfter(months, const YearMonth(2026, 9)), months[2]);
    });

    test('끝 달이면 그쪽 달은 없다', () {
      expect(monthBefore(months, const YearMonth(2026, 3)), isNull);
      expect(monthAfter(months, const YearMonth(2026, 11)), isNull);
      expect(monthAfter(const [], const YearMonth(2026, 11)), isNull);
    });
  });
}
