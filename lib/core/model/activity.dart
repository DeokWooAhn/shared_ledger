/// 변경 기록을 화면에 한 번에 불러오는 개수. 읽기 비용을 줄이려고 이만큼씩 나눠 읽는다.
const activityPageSize = 50;

/// 변경 기록을 두는 기간. 지나면 Firestore TTL 정책이 지운다(`expireAt`).
const activityRetention = Duration(days: 365);

/// 변경 기록 요약의 최대 길이. `firestore.rules`의 validActivity와 같고, 규칙처럼 UTF-16 단위로 센다.
const activitySummaryMaxLength = 200;

/// 변경 기록에 남기는 동작. [code]가 Firestore `action` 값이다(`entry.create` 형식, 규칙이 형식을 확인한다).
///
/// 항목·고정 지출·설정을 바꿀 때 남긴다. 고정 지출로 그달 기본 월 지출을 자동으로 만드는 것은 남기지 않는다.
enum ActivityAction {
  entryCreate('entry.create'),
  entryUpdate('entry.update'),
  entryTrash('entry.trash'),
  entryRestore('entry.restore'),
  entryPurge('entry.purge'),
  templateCreate('template.create'),
  templateUpdate('template.update'),
  templateDelete('template.delete'),
  templateRestore('template.restore'),
  ledgerRename('ledger.rename'),
  memberRename('member.rename'),
  categoryCreate('category.create'),
  categoryUpdate('category.update'),
  categoryHide('category.hide'),
  categoryShow('category.show'),
  paymentMethodCreate('paymentMethod.create'),
  paymentMethodRename('paymentMethod.rename'),
  paymentMethodHide('paymentMethod.hide'),
  paymentMethodShow('paymentMethod.show');

  const ActivityAction(this.code);

  final String code;

  /// Firestore `action` 값의 동작. 모르는 값(새 버전 앱이 남긴 것)이면 null.
  static ActivityAction? fromCode(Object? code) =>
      values.where((action) => action.code == code).firstOrNull;
}

/// 남길 변경 기록. 저장소가 실제 변경과 같은 일괄 쓰기·트랜잭션으로 남긴다.
class ActivityDraft {
  const ActivityDraft(this.action, this.summary);

  final ActivityAction action;

  /// 무엇을 바꿨는지 한 줄. 예: `10월 추가지출 '점심' 12,000원`
  final String summary;

  @override
  bool operator ==(Object other) =>
      other is ActivityDraft &&
      other.action == action &&
      other.summary == summary;

  @override
  int get hashCode => Object.hash(action, summary);

  @override
  String toString() => 'ActivityDraft(${action.code}, $summary)';
}

/// 변경 기록 한 줄. 누가([actorUid]) 언제([at]) 무엇을([action], [summary]) 바꿨는지.
class Activity {
  const Activity({
    required this.id,
    required this.actorUid,
    required this.summary,
    this.action,
    this.at,
  });

  final String id;
  final String actorUid;

  /// 모르는 동작(새 버전 앱이 남긴 것)이면 null.
  final ActivityAction? action;
  final String summary;

  /// 바꾼 때. 오프라인에서 남겨 아직 서버에 닿지 않았으면 null.
  final DateTime? at;

  @override
  bool operator ==(Object other) =>
      other is Activity &&
      other.id == id &&
      other.actorUid == actorUid &&
      other.action == action &&
      other.summary == summary &&
      other.at == at;

  @override
  int get hashCode => Object.hash(id, actorUid, action, summary, at);
}
