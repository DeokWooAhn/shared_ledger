import '../../repository/holidays_repository.dart';
import 'watch_holidays_use_case.dart';

/// 공휴일 UseCase 묶음. 달력이 보는 공휴일 공급자가 읽는다.
class HolidayUseCases {
  HolidayUseCases(HolidaysRepository holidays)
    : watchHolidays = WatchHolidaysUseCase(holidays);

  final WatchHolidaysUseCase watchHolidays;
}
