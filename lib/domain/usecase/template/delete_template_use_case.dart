import '../../repository/templates_repository.dart';

/// [id] 고정 지출을 지운다. 이미 만든 달의 기본 월 지출은 남는다. 온라인에서만 되고, 못 하면 [TemplateWriteException]을 던진다.
class DeleteTemplateUseCase {
  const DeleteTemplateUseCase(this._templates);

  final TemplatesRepository _templates;

  Future<void> call({
    required String ledgerId,
    required String id,
    required String uid,
  }) => _templates.delete(ledgerId: ledgerId, id: id, uid: uid);
}
