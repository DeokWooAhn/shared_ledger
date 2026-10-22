import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/category.dart';
import '../model/member.dart';
import '../model/payment_method.dart';

/// 가계부 설정(이름표·분류·결제수단)을 읽는다. 고치기는 설정 화면을 만들 때 넣는다.
abstract interface class SettingsRepository {
  /// 두 사람의 이름표. owner가 앞에 온다.
  Stream<List<Member>> watchMembers(String ledgerId);

  /// 지출 분류. 정한 순서대로.
  Stream<List<Category>> watchCategories(String ledgerId);

  /// 결제수단. 정한 순서대로.
  Stream<List<PaymentMethod>> watchPaymentMethods(String ledgerId);
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

  // 설정은 몇 개뿐이라 orderBy 대신 앱에서 정렬한다. orderBy는 order가 빠진 문서를 결과에서 빼 버린다.
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _inOrder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) => [...docs]
    ..sort((a, b) {
      final byOrder = settingOrder(a.data()).compareTo(settingOrder(b.data()));
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
}

/// 새 가계부에 넣는 지출 분류. 쓰던 구글 시트와 같다.
const defaultCategories = <({String name, bool countsAsSaving})>[
  (name: '대출원금', countsAsSaving: true),
  (name: '대출이자', countsAsSaving: false),
  (name: '저축/투자', countsAsSaving: true),
  (name: '소비', countsAsSaving: false),
];

/// 새 가계부에 넣는 결제수단. 카드는 사람마다 달라서 직접 추가한다.
const defaultPaymentMethods = <({String name, PaymentKind kind})>[
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
/// `firestore.rules`의 설정 create 규칙(공통 기록 필드, 이름표 id·이름 길이)을 통과해야 한다.
List<NewSettingDoc> defaultSettingDocs({
  required String uid,
  required String ownerName,
}) => [
  (
    collection: 'members',
    id: MemberSlot.owner.name,
    data: {'name': ownerName, ..._createdBy(uid)},
  ),
  (
    collection: 'members',
    id: MemberSlot.partner.name,
    data: {'name': defaultPartnerName, ..._createdBy(uid)},
  ),
  for (final (order, category) in defaultCategories.indexed)
    (
      collection: 'categories',
      id: null,
      data: {
        'name': category.name,
        'countsAsSaving': category.countsAsSaving,
        'order': order,
        ..._createdBy(uid),
      },
    ),
  for (final (order, method) in defaultPaymentMethods.indexed)
    (
      collection: 'paymentMethods',
      id: null,
      data: {
        'name': method.name,
        'kind': method.kind.name,
        'order': order,
        ..._createdBy(uid),
      },
    ),
];

// 설정·항목의 공통 기록 필드(만들 때). 규칙의 createdNow와 같다.
Map<String, Object> _createdBy(String uid) => {
  'createdBy': uid,
  'updatedBy': uid,
  'createdAt': FieldValue.serverTimestamp(),
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
  return PaymentMethod(id: id, name: name, kind: kind);
}
