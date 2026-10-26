import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/holidays.dart';

void main() {
  const holidays = Holidays({'2026-10-03': '개천절', '2026-10-05': '대체공휴일'});

  test('공휴일이면 이름을, 아니면 null을 돌려주고 시각은 보지 않는다', () {
    expect(holidays.nameOf(DateTime(2026, 10, 3)), '개천절');
    expect(holidays.nameOf(DateTime(2026, 10, 5, 23, 59)), '대체공휴일');
    expect(holidays.nameOf(DateTime(2026, 10, 4)), isNull);
    expect(const Holidays().nameOf(DateTime(2026, 10, 3)), isNull);
  });

  test('날짜 키는 달과 날을 두 자리로 쓴다', () {
    expect(holidayKey(DateTime(2027, 2, 9)), '2027-02-09');
  });

  test('같은 날짜·이름이면 같다', () {
    expect(
      holidays,
      const Holidays({'2026-10-05': '대체공휴일', '2026-10-03': '개천절'}),
    );
    expect(holidays, isNot(const Holidays({'2026-10-03': '개천절'})));
    expect(
      holidays,
      isNot(const Holidays({'2026-10-03': '개천절', '2026-10-05': '한글날'})),
    );
  });
}
