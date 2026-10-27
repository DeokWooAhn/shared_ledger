import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/activity.dart';
import '../../domain/model/category.dart';
import '../../domain/model/member.dart';
import '../../domain/model/payment_method.dart';
import '../activity/firestore_activity_repository.dart';
import '../../domain/activity/activity_summary.dart';
import '../../domain/repository/settings_repository.dart';

class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository(this._firestore, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> _settings(
    String ledgerId,
    String name,
  ) => _firestore.collection('ledgers').doc(ledgerId).collection(name);

  @override
  Stream<List<Member>> watchMembers(String ledgerId) =>
      _settings(ledgerId, 'members').snapshots().map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            ?memberFromFirestore(doc.id, doc.data()),
        ]..sort((a, b) => a.slot.index.compareTo(b.slot.index)),
      );

  @override
  Stream<List<Category>> watchCategories(String ledgerId) =>
      _settings(ledgerId, 'categories').snapshots().map(
        (snapshot) => [
          for (final doc in _inOrder(snapshot.docs))
            ?categoryFromFirestore(doc.id, doc.data()),
        ],
      );

  @override
  Stream<List<PaymentMethod>> watchPaymentMethods(String ledgerId) =>
      _settings(ledgerId, 'paymentMethods').snapshots().map(
        (snapshot) => [
          for (final doc in _inOrder(snapshot.docs))
            ?paymentMethodFromFirestore(doc.id, doc.data()),
        ],
      );

  @override
  Future<void> renameMember({
    required String ledgerId,
    required MemberSlot slot,
    required String name,
    required String uid,
  }) {
    final doc = _settings(ledgerId, 'members').doc(slot.name);
    return _writeOnline(ledgerId, uid, (transaction) async {
      final current = (await transaction.get(doc)).data();
      if (current != null) {
        transaction.update(doc, memberRenameUpdate(name, uid: uid));
      } else {
        transaction.set(doc, newMemberData(name, uid: uid));
      }
      return memberRenameActivity(from: _name(current), to: name);
    });
  }

  @override
  Future<String> addCategory({
    required String ledgerId,
    required CategoryDraft draft,
    required int order,
    required String uid,
  }) async {
    final doc = _settings(ledgerId, 'categories').doc();
    await _writeOnline(ledgerId, uid, (transaction) async {
      transaction.set(doc, newCategoryData(draft, order: order, uid: uid));
      return categoryActivity(ActivityAction.categoryCreate, draft.name);
    });
    return doc.id;
  }

  @override
  Future<void> updateCategory({
    required String ledgerId,
    required String id,
    required CategoryDraft draft,
    required String uid,
  }) => _updateExisting(
    ledgerId,
    uid,
    _settings(ledgerId, 'categories').doc(id),
    categoryUpdateData(draft, uid: uid),
    (current) => categoryUpdateActivity(
      fromName: _name(current),
      fromSaving: switch (current['countsAsSaving']) {
        final bool saving => saving,
        _ => null,
      },
      name: draft.name,
      countsAsSaving: draft.countsAsSaving,
    ),
  );

  @override
  Future<void> setCategoryHidden({
    required String ledgerId,
    required String id,
    required bool hidden,
    required String uid,
  }) => _updateExisting(
    ledgerId,
    uid,
    _settings(ledgerId, 'categories').doc(id),
    settingHiddenUpdate(hidden: hidden, uid: uid),
    (current) => categoryActivity(
      hidden ? ActivityAction.categoryHide : ActivityAction.categoryShow,
      _name(current) ?? '',
    ),
  );

  @override
  Future<String> addPaymentMethod({
    required String ledgerId,
    required PaymentMethodDraft draft,
    required int order,
    required String uid,
  }) async {
    final doc = _settings(ledgerId, 'paymentMethods').doc();
    await _writeOnline(ledgerId, uid, (transaction) async {
      transaction.set(doc, newPaymentMethodData(draft, order: order, uid: uid));
      return paymentMethodActivity(
        ActivityAction.paymentMethodCreate,
        draft.name,
        draft.kind,
      );
    });
    return doc.id;
  }

  @override
  Future<void> renamePaymentMethod({
    required String ledgerId,
    required String id,
    required String name,
    required String uid,
  }) => _updateExisting(
    ledgerId,
    uid,
    _settings(ledgerId, 'paymentMethods').doc(id),
    paymentMethodRenameUpdate(name, uid: uid),
    (current) => paymentMethodRenameActivity(
      from: _name(current),
      to: name,
      kind: _kind(current),
    ),
  );

  @override
  Future<void> setPaymentMethodHidden({
    required String ledgerId,
    required String id,
    required bool hidden,
    required String uid,
  }) => _updateExisting(
    ledgerId,
    uid,
    _settings(ledgerId, 'paymentMethods').doc(id),
    settingHiddenUpdate(hidden: hidden, uid: uid),
    (current) => paymentMethodActivity(
      hidden
          ? ActivityAction.paymentMethodHide
          : ActivityAction.paymentMethodShow,
      _name(current) ?? '',
      _kind(current),
    ),
  );

  // 고칠 문서를 읽어 없으면 notFound로 실패한다. 읽은 값(고치기 전)으로 변경 기록을 만든다.
  Future<void> _updateExisting(
    String ledgerId,
    String uid,
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, Object> update,
    ActivityDraft Function(Map<String, dynamic> current) activity,
  ) => _writeOnline(ledgerId, uid, (transaction) async {
    final current = (await transaction.get(doc)).data();
    if (current == null) {
      throw const SettingsWriteException(SettingsWriteFailure.notFound);
    }
    transaction.update(doc, update);
    return activity(current);
  });

  Future<void> _writeOnline(
    String ledgerId,
    String uid,
    Future<ActivityDraft> Function(Transaction transaction) write,
  ) => runSettingsWrite(
    _firestore,
    ledgerId: ledgerId,
    uid: uid,
    now: _now(),
    write: write,
  );

  static String? _name(Map<String, dynamic>? data) => switch (data?['name']) {
    final String name => name,
    _ => null,
  };

  static PaymentKind? _kind(Map<String, dynamic> data) =>
      PaymentKind.values.asNameMap()[data['kind']];

  // 설정은 몇 개뿐이라 orderBy 대신 앱에서 정렬한다. orderBy는 order가 빠진 문서를 결과에서 빼 버린다.
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _inOrder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) => [...docs]
    ..sort((a, b) {
      final byOrder = settingOrder(a.data()).compareTo(settingOrder(b.data()));
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
}

/// 설정 쓰기를 트랜잭션으로 한다. 연결이 없거나 10초 안에 서버가 답하지 않으면
/// [SettingsWriteException]([SettingsWriteFailure.offline])으로 실패한다. 가계부 이름 바꾸기도 쓴다.
///
/// [write]가 돌려준 변경 기록을 [uid]의 이름으로 같은 트랜잭션에 남긴다.
Future<void> runSettingsWrite(
  FirebaseFirestore firestore, {
  required String ledgerId,
  required String uid,
  required DateTime now,
  required Future<ActivityDraft> Function(Transaction transaction) write,
}) async {
  try {
    await firestore.runTransaction((transaction) async {
      final activity = await write(transaction);
      addActivity(
        transaction,
        firestore,
        ledgerId: ledgerId,
        draft: activity,
        uid: uid,
        now: now,
      );
    }, timeout: const Duration(seconds: 10));
  } on FirebaseException catch (e) {
    if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
      throw const SettingsWriteException(SettingsWriteFailure.offline);
    }
    rethrow;
  }
}

/// 가계부를 만들 때 같은 일괄 쓰기로 넣는 설정 문서 하나. [id]가 null이면 저장소가 새 id를 만든다.
typedef NewSettingDoc = ({
  String collection,
  String? id,
  Map<String, Object> data,
});

/// 새 가계부의 기본 설정: 이름표 두 장, 기본 분류, 기본 결제수단.
/// `firestore.rules`의 설정 create 규칙(공통 기록 필드, 이름표 id·이름 길이, 분류·결제수단 필드)을 통과해야 한다.
List<NewSettingDoc> defaultSettingDocs({
  required String uid,
  required String ownerName,
}) => [
  (
    collection: 'members',
    id: MemberSlot.owner.name,
    data: newMemberData(ownerName, uid: uid),
  ),
  (
    collection: 'members',
    id: MemberSlot.partner.name,
    data: newMemberData(defaultPartnerName, uid: uid),
  ),
  for (final (order, category) in defaultCategories.indexed)
    (
      collection: 'categories',
      id: null,
      data: newCategoryData(category, order: order, uid: uid),
    ),
  for (final (order, method) in defaultPaymentMethods.indexed)
    (
      collection: 'paymentMethods',
      id: null,
      data: newPaymentMethodData(method, order: order, uid: uid),
    ),
];

/// 새 이름표 문서. 이름표가 생기기 전에 만든 가계부에서 이름을 처음 바꿀 때도 쓴다.
Map<String, Object> newMemberData(String name, {required String uid}) => {
  'name': name.trim(),
  ..._createdBy(uid),
};

/// 이름표 이름을 바꿀 때 쓰는 값. 규칙의 validMember·updatedNow와 같다.
Map<String, Object> memberRenameUpdate(String name, {required String uid}) => {
  'name': name.trim(),
  ..._updatedBy(uid),
};

/// 새 분류 문서. `firestore.rules`의 validCategory·createdNow와 필드가 같아야 한다.
/// 숨김(hidden)은 숨길 때 처음 생긴다.
Map<String, Object> newCategoryData(
  CategoryDraft draft, {
  required int order,
  required String uid,
}) => {
  'name': draft.name.trim(),
  'countsAsSaving': draft.countsAsSaving,
  'order': order,
  ..._createdBy(uid),
};

/// 분류를 고칠 때 쓰는 값. 순서와 숨김은 그대로 둔다.
Map<String, Object> categoryUpdateData(
  CategoryDraft draft, {
  required String uid,
}) => {
  'name': draft.name.trim(),
  'countsAsSaving': draft.countsAsSaving,
  ..._updatedBy(uid),
};

/// 새 결제수단 문서. `firestore.rules`의 validPaymentMethod·createdNow와 필드가 같아야 한다.
Map<String, Object> newPaymentMethodData(
  PaymentMethodDraft draft, {
  required int order,
  required String uid,
}) => {
  'name': draft.name.trim(),
  'kind': draft.kind.name,
  'order': order,
  ..._createdBy(uid),
};

/// 결제수단 이름을 바꿀 때 쓰는 값. 종류는 바꿀 수 없다(규칙의 keepsKind).
Map<String, Object> paymentMethodRenameUpdate(
  String name, {
  required String uid,
}) => {'name': name.trim(), ..._updatedBy(uid)};

/// 분류·결제수단을 숨기거나 다시 보이게 할 때 쓰는 값.
Map<String, Object> settingHiddenUpdate({
  required bool hidden,
  required String uid,
}) => {'hidden': hidden, ..._updatedBy(uid)};

// 설정·항목의 공통 기록 필드(만들 때). 규칙의 createdNow와 같다.
Map<String, Object> _createdBy(String uid) => {
  'createdBy': uid,
  'updatedBy': uid,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
};

// 고칠 때의 기록 필드. 만든 사람·시간은 그대로 두고 고친 사람·시간만 바꾼다(규칙의 updatedNow).
Map<String, Object> _updatedBy(String uid) => {
  'updatedBy': uid,
  'updatedAt': FieldValue.serverTimestamp(),
};

/// 설정 문서의 정렬 순서. 없거나 숫자가 아니면 맨 뒤.
int settingOrder(Map<String, dynamic> data) => switch (data['order']) {
  final int order => order,
  _ => 1 << 30,
};

/// Firestore 이름표 문서를 [Member]로 바꾼다. 모르는 id거나 이름이 없으면 null.
Member? memberFromFirestore(String id, Map<String, dynamic> data) {
  final slot = MemberSlot.values.asNameMap()[id];
  final name = data['name'];
  if (slot == null || name is! String) return null;
  return Member(slot: slot, name: name);
}

/// Firestore 분류 문서를 [Category]로 바꾼다. 이름이 없으면 null.
Category? categoryFromFirestore(String id, Map<String, dynamic> data) {
  final name = data['name'];
  if (name is! String) return null;
  return Category(
    id: id,
    name: name,
    countsAsSaving: data['countsAsSaving'] == true,
    hidden: data['hidden'] == true,
  );
}

/// Firestore 결제수단 문서를 [PaymentMethod]로 바꾼다. 이름이 없거나 모르는 종류면 null.
PaymentMethod? paymentMethodFromFirestore(
  String id,
  Map<String, dynamic> data,
) {
  final name = data['name'];
  final kind = PaymentKind.values.asNameMap()[data['kind']];
  if (name is! String || kind == null) return null;
  return PaymentMethod(
    id: id,
    name: name,
    kind: kind,
    hidden: data['hidden'] == true,
  );
}
