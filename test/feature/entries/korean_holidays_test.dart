import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/feature/entries/korean_holidays.dart';

void main() {
  test('공휴일과 대체공휴일은 이름을, 평일은 null을 돌려준다', () {
    expect(koreanHoliday(DateTime(2026, 10, 3)), '개천절');
    expect(koreanHoliday(DateTime(2026, 10, 5)), '대체공휴일');
    expect(koreanHoliday(DateTime(2026, 10, 4)), isNull);
    expect(koreanHoliday(DateTime(2026, 10, 6)), isNull);
  });

  test('노동절·제헌절은 2026년부터, 선거일과 임시공휴일도 공휴일이다', () {
    expect(koreanHoliday(DateTime(2026, 5, 1)), '노동절');
    expect(koreanHoliday(DateTime(2027, 7, 19)), '대체공휴일');
    expect(koreanHoliday(DateTime(2025, 5, 1)), isNull);
    expect(koreanHoliday(DateTime(2026, 6, 3)), '지방선거일');
    expect(koreanHoliday(DateTime(2025, 1, 27)), '임시공휴일');
  });

  test('시각은 보지 않는다', () {
    expect(koreanHoliday(DateTime(2027, 2, 9, 23, 59)), '대체공휴일');
  });

  test('표에 없는 해는 공휴일로 보지 않는다', () {
    expect(koreanHoliday(DateTime(2024, 12, 25)), isNull);
    expect(koreanHoliday(DateTime(2028, 1, 1)), isNull);
  });
}
