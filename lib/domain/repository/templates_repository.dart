import '../model/expense_template.dart';
import '../model/ledger_entries.dart';
import '../model/year_month.dart';

/// 고정 지출·고정 수입을 더하거나 고치거나 그만하지 못한 이유.
enum TemplateWriteFailure {
  /// 연결이 없거나 서버가 답하지 않는다. 반복 설정은 두 사람의 목록이 엇갈리지 않게 온라인에서만 바꾼다.
  offline,

  /// 그사이 상대가 그만했거나 그달 항목을 휴지통에 넣었다.
  notFound,
}

class TemplateWriteException implements Exception {
  const TemplateWriteException(this.reason);

  final TemplateWriteFailure reason;

  @override
  String toString() => 'TemplateWriteException($reason)';
}

/// 고정 지출·고정 수입의 반복 설정(템플릿)을 읽고, 고정 지출·고정 수입을 더하거나 고치거나 그만한다.
///
/// 반복 설정과 그달 항목(`months/{달}/planned|fixedIncomes/{같은 id}`, 반복 설정의 종류로 정한다)이 함께 움직인다. 쓰기는 둘을 한 트랜잭션으로 바꾸고,
/// 변경 기록도 같은 트랜잭션으로 남긴다. 서버에 바로 닿아야 해서 연결이 없으면
/// [TemplateWriteException]([TemplateWriteFailure.offline])으로 실패한다.
/// 뒤 달([laterMonths])은 이미 만들어진 달 가운데 고른 달보다 뒤의 달이다. 그 앞의 달은 건드리지 않는다.
abstract interface class TemplatesRepository {
  /// 가계부의 반복 설정 전부. 순서는 화면이 정한다.
  Stream<List<ExpenseTemplate>> watchTemplates(String ledgerId);

  /// 고정 지출·고정 수입을 더하고 id를 돌려준다. 반복 설정 [draft]와 [month]의 항목 [entry]를 같은 id로 만들고,
  /// [laterMonths]에도 반복 설정으로 그달 항목(지급 전·받기 전)을 만든다. 작성자는 [uid]다.
  /// [recordMonth]면 가계부의 항목 있는 달 목록에 [month]를 같이 더한다.
  Future<String> add({
    required String ledgerId,
    required YearMonth month,
    required TemplateDraft draft,
    required EntryDraft entry,
    required List<YearMonth> laterMonths,
    required String uid,
    bool recordMonth = false,
  });

  /// [id] 고정 지출·고정 수입을 고친다. [month]의 항목은 [entry]로, 반복 설정은 [draft]로 바꾼다.
  /// [laterMonths]의 지급 전·받기 전 항목은 반복 설정과 같은 칸(제목·분류·결제수단·누가·예정일)을 맞추고,
  /// 금액은 반복 설정의 금액이 바뀌었을 때만 맞춘다. 반복 설정이나 [month]의 항목이 그사이 없어졌으면 notFound로 실패한다.
  Future<void> update({
    required String ledgerId,
    required String id,
    required YearMonth month,
    required TemplateDraft draft,
    required EntryDraft entry,
    required List<YearMonth> laterMonths,
    required String uid,
  });

  /// [id] 고정 지출·고정 수입을 그만한다. 반복 설정을 지우고 [month]와 [laterMonths]의 지급 전·받기 전 항목을
  /// 휴지통에 넣는다. 지급했거나 받은 항목과 지난 기록(앞의 달)은 남는다. 휴지통에 넣은 달을 돌려준다(되돌리기에 쓴다).
  Future<List<YearMonth>> stop({
    required String ledgerId,
    required String id,
    required YearMonth month,
    required List<YearMonth> laterMonths,
    required String uid,
  });

  /// 그만한 [template]를 되살린다(되돌리기). 반복 설정을 같은 id로 다시 만들고 [months]의 휴지통 항목을 꺼낸다.
  /// 그사이 같은 id의 반복 설정이 생겼거나 항목이 휴지통에 없으면 그것은 그대로 둔다.
  Future<void> resume({
    required String ledgerId,
    required ExpenseTemplate template,
    required List<YearMonth> months,
    required String uid,
  });
}
