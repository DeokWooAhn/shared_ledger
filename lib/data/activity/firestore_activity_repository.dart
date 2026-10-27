import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/activity.dart';
import '../../domain/activity/activity_summary.dart';
import '../../domain/repository/activity_repository.dart';

class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository(this._firestore);

  final FirebaseFirestore _firestore;

  // 단일 필드 정렬이라 자동 색인으로 된다. 시간이 같은 기록은 거의 없어서(서버 시간, 마이크로초) 시간만 커서로 쓴다.
  Query<Map<String, dynamic>> _newestFirst(String ledgerId) =>
      activityCollection(_firestore, ledgerId).orderBy('at', descending: true);

  @override
  Stream<List<Activity>> watchRecent(
    String ledgerId, {
    int limit = activityPageSize,
  }) => _newestFirst(ledgerId)
      .limit(limit)
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            ?activityFromFirestore(doc.id, doc.data()),
        ],
      );

  @override
  Future<List<Activity>> loadOlder(
    String ledgerId, {
    required DateTime before,
    int limit = activityPageSize,
  }) async {
    final snapshot = await _newestFirst(
      ledgerId,
    ).startAfter([Timestamp.fromDate(before)]).limit(limit).get();
    return [
      for (final doc in snapshot.docs)
        ?activityFromFirestore(doc.id, doc.data()),
    ];
  }
}

/// [ledgerId] 가계부의 변경 기록 컬렉션.
CollectionReference<Map<String, dynamic>> activityCollection(
  FirebaseFirestore firestore,
  String ledgerId,
) => firestore.collection('ledgers').doc(ledgerId).collection('activity');

/// 변경 기록 문서. `firestore.rules`의 validActivity와 필드가 같아야 한다.
///
/// 시간은 서버 시간이고, [now]부터 [activityRetention]이 지나면 TTL 정책이 지운다(`expireAt`).
/// 요약은 규칙이 받는 길이로 자른다.
Map<String, Object> newActivityData(
  ActivityDraft draft, {
  required String uid,
  required DateTime now,
}) => {
  'actorUid': uid,
  'at': FieldValue.serverTimestamp(),
  'action': draft.action.code,
  'summary': clampActivitySummary(draft.summary),
  'expireAt': Timestamp.fromDate(now.add(activityRetention)),
};

/// [transaction]에 변경 기록 한 줄을 더한다. 기록과 실제 변경이 함께 쓰이거나 함께 실패한다.
void addActivity(
  Transaction transaction,
  FirebaseFirestore firestore, {
  required String ledgerId,
  required ActivityDraft draft,
  required String uid,
  required DateTime now,
}) => transaction.set(
  activityCollection(firestore, ledgerId).doc(),
  newActivityData(draft, uid: uid, now: now),
);

/// Firestore 변경 기록 문서를 [Activity]로 바꾼다. 바꾼 사람이나 요약이 없으면 null.
///
/// 모르는 동작은 null로 두고 기록은 살린다. 시간이 아직 없으면(서버에 닿기 전) null이다.
Activity? activityFromFirestore(String id, Map<String, dynamic> data) {
  final actorUid = data['actorUid'];
  final summary = data['summary'];
  if (actorUid is! String || summary is! String) return null;
  final at = data['at'];
  return Activity(
    id: id,
    actorUid: actorUid,
    action: ActivityAction.fromCode(data['action']),
    summary: summary,
    at: at is Timestamp ? at.toDate() : null,
  );
}
