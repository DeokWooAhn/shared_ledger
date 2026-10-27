// 한 달 가계부를 이루는 네 가지 항목. 금액 단위는 원이다.

/// 항목 종류. Firestore 컬렉션(`incomes`·`planned`·`extras`·`cardBills`)과 하나씩 맞는다.
enum EntryKind {
  /// 수입
  income,

  /// 기본 월 지출
  planned,

  /// 추가지출
  extra,

  /// 카드대금
  cardBill,
}

/// 항목 제목 길이 제한. `firestore.rules`의 validEntry와 같고, 규칙처럼 UTF-16 단위([String.length])로 센다.
const entryTitleMaxLength = 40;

/// 항목 메모 길이 제한. `firestore.rules`의 validEntry와 같다.
const entryMemoMaxLength = 200;

/// 네 가지 항목의 공통 모양. 목록과 입력 화면이 종류와 상관없이 다룰 때 쓴다.
sealed class LedgerEntry {
  const LedgerEntry();

  String get id;

  EntryKind get kind;

  /// 누구 몫인지. 이름표 자리 이름(`owner`·`partner`)이다.
  String get memberId;

  /// 금액(원). 금액 미정인 기본 월 지출만 null이다.
  int? get amount;

  /// 받은 날·지급한 날·쓴 날·출금일.
  DateTime? get date;

  String? get memo;
}

/// 수입 (실제 입금 기준).
class Income extends LedgerEntry {
  const Income({
    required this.id,
    required this.memberId,
    required this.title,
    required this.amount,
    this.receivedOn,
    this.memo,
  });

  @override
  final String id;
  @override
  final String memberId;
  final String title;
  @override
  final int amount;
  final DateTime? receivedOn;
  @override
  final String? memo;

  @override
  EntryKind get kind => EntryKind.income;

  @override
  DateTime? get date => receivedOn;
}

/// 기본 월 지출. 고정 지출 템플릿에서 매달 만들어진다.
class PlannedExpense extends LedgerEntry {
  const PlannedExpense({
    required this.id,
    required this.categoryId,
    required this.memberId,
    required this.title,
    required this.paymentMethodId,
    this.amount,
    this.paidOn,
    this.dueOn,
    this.memo,
  });

  @override
  final String id;
  final String categoryId;
  @override
  final String memberId;
  final String title;
  final String paymentMethodId;

  /// 아직 금액을 모르면(예: 관리비) null이고, 합계에서는 0원으로 친다.
  @override
  final int? amount;

  /// 실제로 빠져나간 날. 카드가 아닌 지출은 이 값이 있어야 현금 유출에 들어간다.
  final DateTime? paidOn;

  /// 고정 지출에서 옮긴 그달 예정일. 직접 더한 기본 월 지출은 null이다. 계산에는 쓰지 않는다.
  final DateTime? dueOn;
  @override
  final String? memo;

  bool get isPaid => paidOn != null;

  @override
  EntryKind get kind => EntryKind.planned;

  @override
  DateTime? get date => paidOn;
}

/// 추가지출 (예산 밖 지출). 이미 쓴 돈이라 지급 여부를 따로 따지지 않는다.
class ExtraExpense extends LedgerEntry {
  const ExtraExpense({
    required this.id,
    required this.memberId,
    required this.title,
    required this.paymentMethodId,
    required this.amount,
    this.spentOn,
    this.memo,
  });

  @override
  final String id;
  @override
  final String memberId;
  final String title;
  final String paymentMethodId;
  @override
  final int amount;
  final DateTime? spentOn;
  @override
  final String? memo;

  @override
  EntryKind get kind => EntryKind.extra;

  @override
  DateTime? get date => spentOn;
}

/// 카드대금 (이번 달 실제로 출금된 카드값 = 저번 달 카드 사용분).
class CardBill extends LedgerEntry {
  const CardBill({
    required this.id,
    required this.memberId,
    required this.cardId,
    required this.amount,
    this.paidOn,
    this.memo,
  });

  @override
  final String id;
  @override
  final String memberId;

  /// 카드 종류의 [PaymentMethod] id.
  final String cardId;
  @override
  final int amount;
  final DateTime? paidOn;
  @override
  final String? memo;

  @override
  EntryKind get kind => EntryKind.cardBill;

  @override
  DateTime? get date => paidOn;
}

/// 저장할 항목 값. 입력 화면이 만들고 저장소가 Firestore 문서로 바꾼다.
///
/// 종류마다 쓰는 칸이 다르다(docs/firestore.md의 항목 표). 그 종류가 쓰지 않는 칸은 저장하지 않는다.
/// 꼭 필요한 칸이 채워졌는지는 저장 전에 [entryProblemsOf]로 확인한다(입력 화면과 `SaveEntryUseCase`).
class EntryDraft {
  const EntryDraft({
    required this.kind,
    required this.memberId,
    this.amount,
    this.title = '',
    this.categoryId,
    this.paymentMethodId,
    this.cardId,
    this.date,
    this.dueOn,
    this.memo,
  });

  /// 이미 있는 항목의 값. 고치기 화면의 처음 값이다.
  factory EntryDraft.of(LedgerEntry entry) => switch (entry) {
    Income() => EntryDraft(
      kind: EntryKind.income,
      memberId: entry.memberId,
      amount: entry.amount,
      title: entry.title,
      date: entry.receivedOn,
      memo: entry.memo,
    ),
    PlannedExpense() => EntryDraft(
      kind: EntryKind.planned,
      memberId: entry.memberId,
      amount: entry.amount,
      title: entry.title,
      categoryId: entry.categoryId,
      paymentMethodId: entry.paymentMethodId,
      date: entry.paidOn,
      dueOn: entry.dueOn,
      memo: entry.memo,
    ),
    ExtraExpense() => EntryDraft(
      kind: EntryKind.extra,
      memberId: entry.memberId,
      amount: entry.amount,
      title: entry.title,
      paymentMethodId: entry.paymentMethodId,
      date: entry.spentOn,
      memo: entry.memo,
    ),
    CardBill() => EntryDraft(
      kind: EntryKind.cardBill,
      memberId: entry.memberId,
      amount: entry.amount,
      cardId: entry.cardId,
      date: entry.paidOn,
      memo: entry.memo,
    ),
  };

  final EntryKind kind;

  /// 누구 몫인지. 이름표 자리 이름(`owner`·`partner`).
  final String memberId;

  /// 금액(원). 기본 월 지출만 비워 둘 수 있다(금액 미정).
  final int? amount;

  /// 카드대금은 쓰지 않는다.
  final String title;

  /// 기본 월 지출만 쓴다.
  final String? categoryId;

  /// 기본 월 지출과 추가지출만 쓴다.
  final String? paymentMethodId;

  /// 카드대금만 쓴다.
  final String? cardId;

  /// 받은 날·지급한 날·쓴 날·출금일. 기본 월 지출은 이 값이 있어야 지급 완료다.
  final DateTime? date;

  /// 기본 월 지출만 쓴다. 고정 지출에서 옮긴 그달 예정일이고, 입력 화면에서는 고치지 않고 그대로 둔다.
  final DateTime? dueOn;

  /// 비었으면 null.
  final String? memo;

  @override
  bool operator ==(Object other) =>
      other is EntryDraft &&
      other.kind == kind &&
      other.memberId == memberId &&
      other.amount == amount &&
      other.title == title &&
      other.categoryId == categoryId &&
      other.paymentMethodId == paymentMethodId &&
      other.cardId == cardId &&
      other.date == date &&
      other.dueOn == dueOn &&
      other.memo == memo;

  @override
  int get hashCode => Object.hash(
    kind,
    memberId,
    amount,
    title,
    categoryId,
    paymentMethodId,
    cardId,
    date,
    dueOn,
    memo,
  );
}

/// 저장 전에 입력란 아래에 보여 줄 문제.
enum EntryProblem {
  amountMissing,

  /// 금액은 0원부터다(보안 규칙과 같다).
  amountNegative,
  titleMissing,
  titleTooLong,
  categoryMissing,
  paymentMethodMissing,
  cardMissing,
  memoTooLong,
}

/// 저장할 값을 검사한다. 문제가 없으면 빈 집합.
///
/// 금액은 기본 월 지출만 비울 수 있고(금액 미정), 적으면 0원부터다. 제목은 카드대금 말고 꼭 적는다.
/// 길이는 보안 규칙처럼 UTF-16 단위로 센다(`entryTitleMaxLength`).
Set<EntryProblem> entryProblemsOf(EntryDraft draft) {
  final kind = draft.kind;
  final title = draft.title.trim();
  return {
    if (draft.amount == null && kind != EntryKind.planned)
      EntryProblem.amountMissing,
    if ((draft.amount ?? 0) < 0) EntryProblem.amountNegative,
    if (kind != EntryKind.cardBill && title.isEmpty) EntryProblem.titleMissing,
    if (kind != EntryKind.cardBill && title.length > entryTitleMaxLength)
      EntryProblem.titleTooLong,
    if (kind == EntryKind.planned && draft.categoryId == null)
      EntryProblem.categoryMissing,
    if ((kind == EntryKind.planned || kind == EntryKind.extra) &&
        draft.paymentMethodId == null)
      EntryProblem.paymentMethodMissing,
    if (kind == EntryKind.cardBill && draft.cardId == null)
      EntryProblem.cardMissing,
    if ((draft.memo?.trim().length ?? 0) > entryMemoMaxLength)
      EntryProblem.memoTooLong,
  };
}
