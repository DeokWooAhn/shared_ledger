import '../model/expense_template.dart';

/// 고정 지출을 더하거나 고치거나 지우지 못한 이유.
enum TemplateWriteFailure {
  /// 연결이 없거나 서버가 답하지 않는다. 고정 지출은 두 사람의 목록이 엇갈리지 않게 온라인에서만 바꾼다.
  offline,

  /// 그사이 상대가 지웠다.
  notFound,
}

class TemplateWriteException implements Exception {
  const TemplateWriteException(this.reason);

  final TemplateWriteFailure reason;

  @override
  String toString() => 'TemplateWriteException($reason)';
}

/// 고정 지출(템플릿)을 읽고 쓴다. 이 목록으로 새 달의 기본 월 지출이 만들어진다.
///
/// 쓰기는 모두 서버에 바로 닿아야 하는 트랜잭션이라 연결이 없으면
/// [TemplateWriteException]([TemplateWriteFailure.offline])으로 실패한다.
/// 고치거나 지워도 이미 만든 달의 기본 월 지출은 그대로다. 쓸 때마다 변경 기록을 같은 트랜잭션으로 남긴다.
abstract interface class TemplatesRepository {
  /// 가계부의 고정 지출 전부. 순서는 화면이 정한다.
  Stream<List<ExpenseTemplate>> watchTemplates(String ledgerId);

  /// 고정 지출을 더하고 id를 돌려준다. 작성자는 [uid]다.
  Future<String> add({
    required String ledgerId,
    required TemplateDraft draft,
    required String uid,
  });

  /// [id] 고정 지출을 [draft]로 고친다.
  Future<void> update({
    required String ledgerId,
    required String id,
    required TemplateDraft draft,
    required String uid,
  });

  /// [id] 고정 지출을 지운다. 이미 만든 달의 기본 월 지출은 남는다. 변경 기록은 [uid]의 이름으로 남는다.
  Future<void> delete({
    required String ledgerId,
    required String id,
    required String uid,
  });

  /// 지운 [template]를 같은 id로 다시 만든다(되돌리기). 그사이 같은 id의 문서가 생겼으면 그대로 둔다.
  Future<void> restore({
    required String ledgerId,
    required ExpenseTemplate template,
    required String uid,
  });
}
