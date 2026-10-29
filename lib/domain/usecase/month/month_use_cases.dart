import '../../repository/entries_repository.dart';
import '../../repository/ledger_repository.dart';
import 'add_month_use_case.dart';
import 'backfill_months_use_case.dart';
import 'fill_month_from_templates_use_case.dart';
import 'plan_month_fill_use_case.dart';
import 'plan_months_backfill_use_case.dart';

/// 달 UseCase 묶음: 반복 설정으로 그달 채우기, 달력·가계부 탭에서 그달 만들기, 옛 가계부의 달 목록 처음 모으기.
/// 홈 틀과 항목·가계부 탭이 읽는다.
class MonthUseCases {
  MonthUseCases(
    EntriesRepository entries,
    LedgerRepository ledgers, {
    required DateTime Function() now,
  }) : planMonthFill = PlanMonthFillUseCase(now),
       fillMonthFromTemplates = FillMonthFromTemplatesUseCase(entries),
       addMonth = AddMonthUseCase(entries, now),
       planMonthsBackfill = PlanMonthsBackfillUseCase(now),
       backfillMonths = BackfillMonthsUseCase(entries, ledgers, now);

  final PlanMonthFillUseCase planMonthFill;
  final FillMonthFromTemplatesUseCase fillMonthFromTemplates;
  final AddMonthUseCase addMonth;
  final PlanMonthsBackfillUseCase planMonthsBackfill;
  final BackfillMonthsUseCase backfillMonths;
}
