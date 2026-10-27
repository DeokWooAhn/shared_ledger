import 'ledger_entries.dart';
import 'month_ledger.dart';
import 'year_month.dart';

/// 예정일 '말일'. 31일로 적고 '말일'로 보여준다. 31일이 없는 달에도 그달 마지막 날이 된다.
const lastDueDay = 31;

/// 고정 지출(템플릿). 매달 나가는 돈이고, 이 목록으로 그달 기본 월 지출이 만들어진다.
///
/// Firestore 문서 id가 그달 기본 월 지출의 문서 id가 된다(`months/{yyyy-MM}/planned/{템플릿 id}`).
class ExpenseTemplate {
  const ExpenseTemplate({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.paymentMethodId,
    required this.memberId,
    required this.dueDay,
    this.amount,
  });

  final String id;
  final String title;

  /// 매달 나가는 금액(원). 달마다 다르면(관리비) null이고, 합계에서는 0원으로 친다.
  final int? amount;
  final String categoryId;
  final String paymentMethodId;

  /// 누구 몫인지. 이름표 자리 이름(`owner`·`partner`).
  final String memberId;

  /// 매달 예정일(1~31). [lastDueDay]는 말일이다.
  final int dueDay;

  bool get dueOnLastDay => dueDay == lastDueDay;

  /// [month]에서의 예정일. 그달에 없는 날(2월 30일)이면 그달 말일이다.
  DateTime dueOn(YearMonth month) {
    final last = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, dueDay < last ? dueDay : last);
  }

  /// [month]에 만들 기본 월 지출. 지급 전으로 만들고 예정일을 옮긴다.
  EntryDraft draftFor(YearMonth month) => EntryDraft(
    kind: EntryKind.planned,
    memberId: memberId,
    amount: amount,
    title: title,
    categoryId: categoryId,
    paymentMethodId: paymentMethodId,
    dueOn: dueOn(month),
  );

  @override
  bool operator ==(Object other) =>
      other is ExpenseTemplate &&
      other.id == id &&
      other.title == title &&
      other.amount == amount &&
      other.categoryId == categoryId &&
      other.paymentMethodId == paymentMethodId &&
      other.memberId == memberId &&
      other.dueDay == dueDay;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    amount,
    categoryId,
    paymentMethodId,
    memberId,
    dueDay,
  );
}

/// 저장할 고정 지출 값. 입력 화면이 만들고 저장소가 Firestore 문서로 바꾼다.
///
/// 꼭 필요한 칸이 채워졌는지는 입력 화면이 저장 전에 확인한다.
class TemplateDraft {
  const TemplateDraft({
    required this.memberId,
    this.title = '',
    this.amount,
    this.categoryId,
    this.paymentMethodId,
    this.dueDay,
  });

  /// 이미 있는 고정 지출의 값. 고치기 화면의 처음 값이고, 지운 것을 되돌릴 때도 쓴다.
  factory TemplateDraft.of(ExpenseTemplate template) => TemplateDraft(
    memberId: template.memberId,
    title: template.title,
    amount: template.amount,
    categoryId: template.categoryId,
    paymentMethodId: template.paymentMethodId,
    dueDay: template.dueDay,
  );

  final String memberId;
  final String title;

  /// 비어 있으면 금액 미정.
  final int? amount;
  final String? categoryId;
  final String? paymentMethodId;

  /// 1~31. [lastDueDay]는 말일.
  final int? dueDay;

  @override
  bool operator ==(Object other) =>
      other is TemplateDraft &&
      other.memberId == memberId &&
      other.title == title &&
      other.amount == amount &&
      other.categoryId == categoryId &&
      other.paymentMethodId == paymentMethodId &&
      other.dueDay == dueDay;

  @override
  int get hashCode =>
      Object.hash(memberId, title, amount, categoryId, paymentMethodId, dueDay);
}

/// [month]의 기본 월 지출을 고정 지출로 자동으로 채우는지. 이번 달과 다음 달만 채운다.
///
/// 지난 달은 이미 지나간 기록이라 고정 지출로 덮지 않고, 먼 미래 달은 미리 만들지 않는다.
bool fillsFromTemplates(YearMonth month, {required YearMonth thisMonth}) =>
    month == thisMonth || month == thisMonth.next;

/// 달력에서 [month] 가계부를 새로 만들 때 고정 지출로 채우는지. 이번 달과 앞으로의 달만 채우고, 지난 달은 달만 만든다.
bool fillsTemplatesOnAdd(YearMonth month, {required YearMonth thisMonth}) =>
    month.compareTo(thisMonth) >= 0;

/// [templates] 가운데 [ledger]의 달에 아직 기본 월 지출이 없는 것.
///
/// 문서 id가 템플릿 id라서, 휴지통에 넣은 것을 포함해 그 id의 문서가 있으면 다시 만들지 않는다.
List<ExpenseTemplate> templatesMissingIn(
  MonthLedger ledger,
  List<ExpenseTemplate> templates,
) {
  final existing = ledger.plannedIds;
  return [
    for (final template in templates)
      if (!existing.contains(template.id)) template,
  ];
}

/// 저장 전에 입력란 아래에 보여 줄 문제. 금액은 비워 둘 수 있어서(금액 미정) 문제가 없다.
enum TemplateProblem {
  titleMissing,
  titleTooLong,
  categoryMissing,
  paymentMethodMissing,
  dueDayMissing,
}

/// 저장할 값을 검사한다. 문제가 없으면 빈 집합.
///
/// 제목 길이는 항목과 같이 보안 규칙처럼 UTF-16 단위로 센다(`entryTitleMaxLength`).
Set<TemplateProblem> templateProblemsOf(TemplateDraft draft) {
  final title = draft.title.trim();
  return {
    if (title.isEmpty) TemplateProblem.titleMissing,
    if (title.length > entryTitleMaxLength) TemplateProblem.titleTooLong,
    if (draft.categoryId == null) TemplateProblem.categoryMissing,
    if (draft.paymentMethodId == null) TemplateProblem.paymentMethodMissing,
    if (draft.dueDay == null) TemplateProblem.dueDayMissing,
  };
}
