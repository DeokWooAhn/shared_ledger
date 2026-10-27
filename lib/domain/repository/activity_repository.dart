import '../model/activity.dart';

/// 가계부의 변경 기록을 읽는다.
///
/// 기록은 항목·고정 지출·설정을 쓰는 저장소가 같은 일괄 쓰기·트랜잭션으로 남긴다(구현은 data의 `newActivityData`).
/// 계속 늘어나는 목록이라 최근 것부터 [activityPageSize]건씩만 읽는다.
abstract interface class ActivityRepository {
  /// 최근 변경 기록 [limit]건, 새것부터. 새 기록이 생기면 다시 알린다.
  ///
  /// 오프라인에서 남겨 아직 서버에 닿지 않은 기록(시간이 null)이 맨 앞에 온다.
  Stream<List<Activity>> watchRecent(
    String ledgerId, {
    int limit = activityPageSize,
  });

  /// [before]보다 먼저 남긴 변경 기록 [limit]건, 새것부터. 한 번만 읽는다('더 보기').
  Future<List<Activity>> loadOlder(
    String ledgerId, {
    required DateTime before,
    int limit = activityPageSize,
  });
}
