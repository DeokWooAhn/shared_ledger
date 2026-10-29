import '../../repository/templates_repository.dart';
import 'add_fixed_expense_use_case.dart';
import 'resume_fixed_expense_use_case.dart';
import 'stop_fixed_expense_use_case.dart';
import 'update_fixed_expense_use_case.dart';
import 'watch_templates_use_case.dart';

/// 고정 지출 UseCase 묶음. 반복 설정 공급자, 항목 입력 화면, 항목 탭(되돌리기)이 읽는다.
class TemplateUseCases {
  TemplateUseCases(TemplatesRepository templates)
    : watchTemplates = WatchTemplatesUseCase(templates),
      addFixedExpense = AddFixedExpenseUseCase(templates),
      updateFixedExpense = UpdateFixedExpenseUseCase(templates),
      stopFixedExpense = StopFixedExpenseUseCase(templates),
      resumeFixedExpense = ResumeFixedExpenseUseCase(templates);

  final WatchTemplatesUseCase watchTemplates;
  final AddFixedExpenseUseCase addFixedExpense;
  final UpdateFixedExpenseUseCase updateFixedExpense;
  final StopFixedExpenseUseCase stopFixedExpense;
  final ResumeFixedExpenseUseCase resumeFixedExpense;
}
