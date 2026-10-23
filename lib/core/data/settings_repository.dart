import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/category.dart';
import '../model/member.dart';
import '../model/payment_method.dart';

/// 설정(가계부 이름·이름표·분류·결제수단)을 바꾸지 못한 이유.
enum SettingsWriteFailure {
  /// 연결이 없거나 서버가 답하지 않는다. 설정은 두 사람의 화면이 엇갈리지 않게 온라인에서만 바꾼다.
  offline,

  /// 고칠 문서가 없다. 그사이 가계부에서 나갔거나 가계부가 지워졌다.
  notFound,
}

class SettingsWriteException implements Exception {
  const SettingsWriteException(this.reason);

  final SettingsWriteFailure reason;

  @override
  String toString() => 'SettingsWriteException($reason)';
}

/// 새로 만들거나 고칠 분류의 값.
typedef CategoryDraft = ({String name, bool countsAsSaving});

/// 새로 만들 결제수단의 값. 종류는 만든 뒤에 바꿀 수 없다.
typedef PaymentMethodDraft = ({String name, PaymentKind kind});

/// 가계부 설정(이름표·분류·결제수단)을 읽고 고친다.
///
/// 분류·결제수단은 지우지 않고 숨긴다. 지난 항목이 가리키고 있어서 지우면 지난 달 합계가 바뀐다.
/// 쓰기는 모두 서버에 바로 닿아야 하는 트랜잭션이라 연결이 없으면
/// [SettingsWriteException]([SettingsWriteFailure.offline])으로 실패한다.
abstract interface class SettingsRepository {
  /// 두 사람의 이름표. owner가 앞에 온다.
  Stream<List<Member>> watchMembers(String ledgerId);

  /// 지출 분류. 정한 순서대로, 숨긴 분류도 함께.
  Stream<List<Category>> watchCategories(String ledgerId);

  /// 결제수단. 정한 순서대로, 숨긴 결제수단도 함께.
  Stream<List<PaymentMethod>> watchPaymentMethods(String ledgerId);

  /// [slot] 이름표의 이름을 [name]으로 바꾼다. 이름표가 생기기 전에 만든 가계부면 이름표를 만든다.
  Future<void> renameMember({
    required String ledgerId,
    required MemberSlot slot,
    required String name,
    required String uid,
  });

  /// 분류를 더하고 id를 돌려준다. [order]는 보여줄 순서로, 맨 뒤에 붙이려면 지금 분류 개수를 넘긴다.
  Future<String> addCategory({
    required String ledgerId,
    required CategoryDraft draft,
    required int order,
    required String uid,
  });

  /// [id] 분류의 이름과 저축 집계를 [draft]로 고친다.
  Future<void> updateCategory({
    required String ledgerId,
    required String id,
    required CategoryDraft draft,
    required String uid,
  });

  /// [id] 분류를 숨기거나([hidden]이 true) 다시 보이게 한다.
  Future<void> setCategoryHidden({
    required String ledgerId,
    required String id,
    required bool hidden,
    required String uid,
  });

  /// 결제수단을 더하고 id를 돌려준다. [order]는 [addCategory]와 같다.
  Future<String> addPaymentMethod({
    required String ledgerId,
    required PaymentMethodDraft draft,
    required int order,
    required String uid,
  });

  /// [id] 결제수단의 이름을 바꾼다. 종류는 바꿀 수 없다.
  Future<void> renamePaymentMethod({
    required String ledgerId,
    required String id,
    required String name,
    required String uid,
  });

  /// [id] 결제수단을 숨기거나([hidden]이 true) 다시 보이게 한다.
  Future<void> setPaymentMethodHidden({
    required String ledgerId,
    required String id,
    required bool hidden,
    required String uid,
  });
}

class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

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
    return _writeOnline((transaction) async {
      if ((await transaction.get(doc)).exists) {
        transaction.update(doc, memberRenameUpdate(name, uid: uid));
      } else {
        transaction.set(doc, newMemberData(name, uid: uid));
      }
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
    await _writeOnline((transaction) async {
      transaction.set(doc, newCategoryData(draft, order: order, uid: uid));
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
    _settings(ledgerId, 'categories').doc(id),
    categoryUpdateData(draft, uid: uid),
  );

  @override
  Future<void> setCategoryHidden({
    required String ledgerId,
    required String id,
    required bool hidden,
    required String uid,
  }) => _updateExisting(
    _settings(ledgerId, 'categories').doc(id),
    settingHiddenUpdate(hidden: hidden, uid: uid),
  );

  @override
  Future<String> addPaymentMethod({
    required String ledgerId,
    required PaymentMethodDraft draft,
    required int order,
    required String uid,
  }) async {
    final doc = _settings(ledgerId, 'paymentMethods').doc();
    await _writeOnline((transaction) async {
      transaction.set(doc, newPaymentMethodData(draft, order: order, uid: uid));
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
    _settings(ledgerId, 'paymentMethods').doc(id),
    paymentMethodRenameUpdate(name, uid: uid),
  );

  @override
  Future<void> setPaymentMethodHidden({
    required String ledgerId,
    required String id,
    required bool hidden,
    required String uid,
  }) => _updateExisting(
    _settings(ledgerId, 'paymentMethods').doc(id),
    settingHiddenUpdate(hidden: hidden, uid: uid),
  );

  Future<void> _updateExisting(
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, Object> update,
  ) => _writeOnline((transaction) async {
    if (!(await transaction.get(doc)).exists) {
      throw const SettingsWriteException(SettingsWriteFailure.notFound);
    }
    transaction.update(doc, update);
  });

  // 트랜잭션은 서버에 닿아야 끝나서 오프라인이면 실패한다. 연결이 끊긴 채로 오래 기다리지 않게 10초만 기다린다.
  Future<void> _writeOnline(
    Future<void> Function(Transaction transaction) write,
  ) => runSettingsWrite(_firestore, write);

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
Future<void> runSettingsWrite(
  FirebaseFirestore firestore,
  Future<void> Function(Transaction transaction) write,
) async {
  try {
    await firestore.runTransaction(write, timeout: const Duration(seconds: 10));
  } on FirebaseException catch (e) {
    if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
      throw const SettingsWriteException(SettingsWriteFailure.offline);
    }
    rethrow;
  }
}

/// 새 가계부에 넣는 지출 분류. 쓰던 구글 시트와 같다.
const defaultCategories = <CategoryDraft>[
  (name: '대출원금', countsAsSaving: true),
  (name: '대출이자', countsAsSaving: false),
  (name: '저축/투자', countsAsSaving: true),
  (name: '소비', countsAsSaving: false),
];

/// 새 가계부에 넣는 결제수단. 카드는 사람마다 달라서 직접 추가한다.
const defaultPaymentMethods = <PaymentMethodDraft>[
  (name: '공동 통장', kind: PaymentKind.account),
  (name: '자동이체', kind: PaymentKind.autoTransfer),
];

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
