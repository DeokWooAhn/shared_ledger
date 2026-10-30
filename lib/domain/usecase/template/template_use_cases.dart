import '../../repository/templates_repository.dart';
import 'add_fixed_entry_use_case.dart';
import 'resume_fixed_entry_use_case.dart';
import 'stop_fixed_entry_use_case.dart';
import 'update_fixed_entry_use_case.dart';
import 'watch_templates_use_case.dart';

/// 반복 설정(고정 지출·고정 수입) UseCase 묶음. 반복 설정 공급자, 항목 입력 화면, 항목 탭(되돌리기)이 읽는다.
class TemplateUseCases {
  TemplateUseCases(TemplatesRepository templates)
    : watchTemplates = WatchTemplatesUseCase(templates),
      addFixedEntry = AddFixedEntryUseCase(templates),
      updateFixedEntry = UpdateFixedEntryUseCase(templates),
      stopFixedEntry = StopFixedEntryUseCase(templates),
      resumeFixedEntry = ResumeFixedEntryUseCase(templates);

  final WatchTemplatesUseCase watchTemplates;
  final AddFixedEntryUseCase addFixedEntry;
  final UpdateFixedEntryUseCase updateFixedEntry;
  final StopFixedEntryUseCase stopFixedEntry;
  final ResumeFixedEntryUseCase resumeFixedEntry;
}
