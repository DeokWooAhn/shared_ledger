import '../model/holidays.dart';

/// 공휴일 읽기. 쓰기는 Cloud Functions가 하고 앱은 읽기만 한다(`firestore.rules`의 holidays).
abstract interface class HolidaysRepository {
  /// [year]년 공휴일(`holidays/{year}`)을 구독한다. 아직 받아 둔 것이 없으면 빈 해다.
  Stream<Holidays> watchYear(int year);
}
