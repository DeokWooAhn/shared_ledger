import '../model/activity.dart';
import '../model/expense_template.dart';
import '../model/ledger_entries.dart';
import '../model/payment_method.dart';
import '../model/year_month.dart';
import '../format/won.dart';

// 변경 기록 한 줄(summary)을 만드는 함수. 저장소가 실제로 쓰는 값으로 만들어서 기록과 변경이 어긋나지 않는다.
// 누가·언제는 따로 저장하고 여기서는 무엇을 바꿨는지만 적는다. 예: `10월 추가 지출 '점심' 12,000원`
// 요약은 Firestore에만 저장하고 로그에는 남기지 않는다(금액·제목이 들어 있다).

/// 항목 변경 기록. [entry]는 쓴 뒤의 값(휴지통·되살리기·완전 삭제는 그 항목의 값)이다.
///
/// 고쳤으면 [before]와 견줘 바뀐 칸을 붙인다. 제목·금액이 바뀌면 앞뒤 값을, 다른 칸은 이름만 적는다.
/// 예: `10월 추가 지출 '점심' · 금액 12,000원 → 15,000원, 쓴 날`
/// 문서를 읽지 못했으면(모양이 잘못된 문서) [entry]가 null이고 달과 종류만 적는다.
ActivityDraft entryActivity(
  ActivityAction action, {
  required YearMonth month,
  required EntryKind kind,
  EntryDraft? entry,
  EntryDraft? before,
}) {
  final head = '${month.month}월 ${_entryKindLabel(kind)}';
  if (entry == null) return ActivityDraft(action, head);
  final changes = <String>[
    if (before != null) ...[
      if (before.title.trim() != entry.title.trim())
        "제목 ${_quoted(before.title)} → ${_quoted(entry.title)}",
      if (before.amount != entry.amount)
        _amountChange(before.amount, entry.amount),
      if (before.memberId != entry.memberId) '누가',
      if (before.categoryId != entry.categoryId) '분류',
      if (before.paymentMethodId != entry.paymentMethodId) '결제수단',
      if (before.cardId != entry.cardId) '카드',
      if (before.date != entry.date) _entryDateLabel(kind),
      if ((before.memo?.trim() ?? '') != (entry.memo?.trim() ?? '')) '메모',
    ],
  ];
  final titleChanged =
      before != null && before.title.trim() != entry.title.trim();
  final amountChanged = before != null && before.amount != entry.amount;
  final summary = [
    head,
    if (!titleChanged && entry.title.trim().isNotEmpty) _quoted(entry.title),
    if (!amountChanged) _amount(entry.amount),
  ].join(' ');
  return ActivityDraft(
    action,
    changes.isEmpty ? summary : '$summary · ${changes.join(', ')}',
  );
}

/// 고정 지출 변경 기록. 예: `고정 지출 '월세' 500,000원`, 고쳤으면 `고정 지출 '월세' · 금액 500,000원 → 550,000원, 예정일`
///
/// 지울 반복 설정 문서의 모양이 잘못돼 값을 읽지 못했으면 [template]이 null이고 '고정 지출'만 적는다.
ActivityDraft templateActivity(
  ActivityAction action,
  TemplateDraft? template, {
  TemplateDraft? before,
}) {
  if (template == null) return ActivityDraft(action, '고정 지출');
  final titleChanged =
      before != null && before.title.trim() != template.title.trim();
  final amountChanged = before != null && before.amount != template.amount;
  final changes = <String>[
    if (before != null) ...[
      if (titleChanged)
        "제목 ${_quoted(before.title)} → ${_quoted(template.title)}",
      if (amountChanged) _amountChange(before.amount, template.amount),
      if (before.memberId != template.memberId) '누가',
      if (before.categoryId != template.categoryId) '분류',
      if (before.paymentMethodId != template.paymentMethodId) '결제수단',
      if (before.dueDay != template.dueDay) '예정일',
    ],
  ];
  final summary = [
    '고정 지출',
    if (!titleChanged) _quoted(template.title),
    if (!amountChanged) _amount(template.amount),
  ].join(' ');
  return ActivityDraft(
    action,
    changes.isEmpty ? summary : '$summary · ${changes.join(', ')}',
  );
}

/// 가계부 이름을 바꾼 기록. 예: `가계부 이름 '우리 가계부' → '하늘바다 가계부'`
ActivityDraft ledgerRenameActivity({String? from, required String to}) =>
    ActivityDraft(ActivityAction.ledgerRename, '가계부 이름 ${_renamed(from, to)}');

/// 이름표 이름을 바꾼 기록. 이름표가 없던 옛 가계부면 [from]이 null이다. 예: `이름표 '상대' → '바다'`
ActivityDraft memberRenameActivity({String? from, required String to}) =>
    ActivityDraft(ActivityAction.memberRename, '이름표 ${_renamed(from, to)}');

/// 분류를 더하거나 숨기거나 다시 보이게 한 기록. 예: `분류 '여행'`
ActivityDraft categoryActivity(ActivityAction action, String name) =>
    ActivityDraft(action, '분류 ${_quoted(name)}');

/// 분류를 고친 기록. 이름이 바뀌면 앞뒤 이름을, 저축 집계가 바뀌면 켬·끔을 적는다.
/// 예: `분류 '여행' → '휴가' · 저축 집계 켬`
ActivityDraft categoryUpdateActivity({
  String? fromName,
  bool? fromSaving,
  required String name,
  required bool countsAsSaving,
}) {
  final summary = '분류 ${_renamed(fromName, name)}';
  return ActivityDraft(
    ActivityAction.categoryUpdate,
    fromSaving == null || fromSaving == countsAsSaving
        ? summary
        : '$summary · 저축 집계 ${countsAsSaving ? '켬' : '끔'}',
  );
}

/// 결제수단을 더하거나 숨기거나 다시 보이게 한 기록. 카드는 '카드'로 적는다. 예: `카드 '하늘카드'`
ActivityDraft paymentMethodActivity(
  ActivityAction action,
  String name,
  PaymentKind? kind,
) => ActivityDraft(action, '${_methodLabel(kind)} ${_quoted(name)}');

/// 결제수단 이름을 바꾼 기록. 예: `카드 '하늘카드' → '하늘 체크카드'`
ActivityDraft paymentMethodRenameActivity({
  String? from,
  required String to,
  PaymentKind? kind,
}) => ActivityDraft(
  ActivityAction.paymentMethodRename,
  '${_methodLabel(kind)} ${_renamed(from, to)}',
);

/// 규칙이 받는 길이([activitySummaryMaxLength])로 자른다. 이모지가 반쪽이 되지 않게 글자 단위로 자른다.
String clampActivitySummary(String summary) {
  if (summary.length <= activitySummaryMaxLength) return summary;
  final buffer = StringBuffer();
  for (final rune in summary.runes) {
    final char = String.fromCharCode(rune);
    if (buffer.length + char.length > activitySummaryMaxLength - 1) break;
    buffer.write(char);
  }
  return '$buffer…';
}

String _entryKindLabel(EntryKind kind) => switch (kind) {
  EntryKind.income => '수입',
  EntryKind.planned => '고정 지출',
  EntryKind.extra => '추가 지출',
  EntryKind.cardBill => '카드 대금',
};

String _entryDateLabel(EntryKind kind) => switch (kind) {
  EntryKind.income => '받은 날',
  EntryKind.planned => '지급한 날',
  EntryKind.extra => '쓴 날',
  EntryKind.cardBill => '출금일',
};

String _methodLabel(PaymentKind? kind) =>
    kind == PaymentKind.card ? '카드' : '결제수단';

String _quoted(String text) => "'${text.trim()}'";

String _amount(int? amount) => amount == null ? '금액 미정' : won(amount);

// 예: '금액 12,000원 → 15,000원', '금액 미정 → 210,000원'
String _amountChange(int? from, int? to) =>
    '금액 ${from == null ? '미정' : won(from)} → ${to == null ? '미정' : won(to)}';

String _renamed(String? from, String to) =>
    from == null || from.trim() == to.trim()
    ? _quoted(to)
    : '${_quoted(from)} → ${_quoted(to)}';
