import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/household.dart';

/// 가구 이름 길이 제한. `firestore.rules`의 validName과 같다.
const householdNameMaxLength = 40;

abstract interface class HouseholdRepository {
  /// 내가 속한 가구 목록. 먼저 만든 가구가 앞에 온다.
  Stream<List<Household>> watchMyHouseholds(String uid);

  /// 나를 관리자로 하는 가구를 만들고 id를 돌려준다.
  Future<String> create({required String name, required String ownerUid});
}

class FirestoreHouseholdRepository implements HouseholdRepository {
  FirestoreHouseholdRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _households =>
      _firestore.collection('households');

  @override
  Stream<List<Household>> watchMyHouseholds(String uid) => _households
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((snapshot) {
        final docs = [...snapshot.docs]..sort(_byCreatedAt);
        return [
          for (final doc in docs) householdFromFirestore(doc.id, doc.data()),
        ];
      });

  @override
  Future<String> create({
    required String name,
    required String ownerUid,
  }) async {
    final ref = _households.doc();
    await ref.set(newHouseholdData(name: name, ownerUid: ownerUid));
    return ref.id;
  }

  // 방금 만든 가구는 서버 시간이 아직 없어서(null) 맨 뒤로 보낸다.
  static int _byCreatedAt(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aTime = a.data()['createdAt'];
    final bTime = b.data()['createdAt'];
    if (aTime is Timestamp && bTime is Timestamp) return aTime.compareTo(bTime);
    if (aTime is Timestamp) return -1;
    if (bTime is Timestamp) return 1;
    return a.id.compareTo(b.id);
  }
}

/// 가구를 만들 때 쓰는 문서. `firestore.rules`의 households create 규칙과 필드가 같아야 한다.
Map<String, Object> newHouseholdData({
  required String name,
  required String ownerUid,
}) => {
  'name': name,
  'ownerUid': ownerUid,
  'roles': <String, String>{},
  'memberUids': [ownerUid],
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
};

/// Firestore 문서를 [Household]로 바꾼다. 알 수 없는 역할 값은 건너뛴다.
Household householdFromFirestore(String id, Map<String, dynamic> data) {
  final rawRoles = data['roles'];
  final roles = <String, HouseholdRole>{};
  if (rawRoles is Map) {
    for (final MapEntry(:key, :value) in rawRoles.entries) {
      final role = switch (value) {
        'editor' => HouseholdRole.editor,
        'viewer' => HouseholdRole.viewer,
        _ => null,
      };
      if (key is String && role != null) roles[key] = role;
    }
  }
  return Household(
    id: id,
    name: data['name'] as String? ?? '',
    ownerUid: data['ownerUid'] as String? ?? '',
    roles: roles,
  );
}
