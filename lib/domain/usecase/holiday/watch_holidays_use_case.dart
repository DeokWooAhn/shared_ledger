import '../../model/holidays.dart';
import '../../repository/holidays_repository.dart';

/// [year]년 공휴일을 지켜본다(문서 하나). 아직 받아 둔 것이 없으면 빈 해다. 쓰기는 Cloud Functions가 한다.
class WatchHolidaysUseCase {
  const WatchHolidaysUseCase(this._holidays);

  final HolidaysRepository _holidays;

  Stream<Holidays> call(int year) => _holidays.watchYear(year);
}
