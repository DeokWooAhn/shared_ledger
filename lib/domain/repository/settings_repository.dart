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
/// [SettingsWriteException]([SettingsWriteFailure.offline])으로 실패한다. 쓸 때마다 변경 기록을 같은 트랜잭션으로 남긴다.
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
