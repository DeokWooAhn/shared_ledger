import '../../repository/templates_repository.dart';
import 'delete_template_use_case.dart';
import 'restore_template_use_case.dart';
import 'save_template_use_case.dart';
import 'watch_templates_use_case.dart';

/// 고정 지출 UseCase 묶음. 고정 지출 공급자, 고정 지출 탭과 입력 화면이 읽는다.
class TemplateUseCases {
  TemplateUseCases(TemplatesRepository templates)
    : watchTemplates = WatchTemplatesUseCase(templates),
      saveTemplate = SaveTemplateUseCase(templates),
      deleteTemplate = DeleteTemplateUseCase(templates),
      restoreTemplate = RestoreTemplateUseCase(templates);

  final WatchTemplatesUseCase watchTemplates;
  final SaveTemplateUseCase saveTemplate;
  final DeleteTemplateUseCase deleteTemplate;
  final RestoreTemplateUseCase restoreTemplate;
}
