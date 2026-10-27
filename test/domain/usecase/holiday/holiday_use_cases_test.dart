import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/holidays.dart';
import 'package:shared_ledger/domain/usecase/holiday/holiday_use_cases.dart';

import '../../../../testing/fakes.dart';

void main() {
  test('그해 공휴일을 지켜보고, 받아 둔 것이 없으면 빈 해다', () async {
    final holidays = FakeHolidaysRepository({
      2026: const Holidays({'2026-10-03': '개천절'}),
    });
    final useCases = HolidayUseCases(holidays);

    expect(
      (await useCases.watchHolidays(2026).first).nameOf(DateTime(2026, 10, 3)),
      '개천절',
    );
    expect(await useCases.watchHolidays(2027).first, const Holidays());
    expect(holidays.watched, [2026, 2027]);
  });
}
