import 'calculate_month_summary_use_case.dart';

/// 월 요약 UseCase 묶음. 요약 공급자가 읽는다. 저장소 없이 계산만 한다.
class SummaryUseCases {
  const SummaryUseCases()
    : calculateMonthSummary = const CalculateMonthSummaryUseCase();

  final CalculateMonthSummaryUseCase calculateMonthSummary;
}
