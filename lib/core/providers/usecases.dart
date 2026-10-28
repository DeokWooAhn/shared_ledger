import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecase/activity/activity_use_cases.dart';
import '../../domain/usecase/auth/auth_use_cases.dart';
import '../../domain/usecase/entry/entry_use_cases.dart';
import '../../domain/usecase/holiday/holiday_use_cases.dart';
import '../../domain/usecase/ledger/ledger_use_cases.dart';
import '../../domain/usecase/month/month_use_cases.dart';
import '../../domain/usecase/settings/settings_use_cases.dart';
import '../../domain/usecase/summary/summary_use_cases.dart';
import '../../domain/usecase/template/template_use_cases.dart';
import 'clock.dart';
import 'repositories.dart';

// UseCase 묶음 공급자. Notifier와 공급자(providers.dart)는 저장소 대신 이것을 읽는다.
// 묶음은 저장소 공급자로 만들어서, 테스트가 저장소 자리에 가짜를 넣으면 UseCase도 그 가짜를 쓴다.
// 시간이 필요한 UseCase는 clockProvider로 받는다(테스트는 testNow로 고정한다).

final authUseCasesProvider = Provider<AuthUseCases>(
  (ref) => AuthUseCases(ref.watch(authRepositoryProvider)),
);

final ledgerUseCasesProvider = Provider<LedgerUseCases>(
  (ref) => LedgerUseCases(ref.watch(ledgerRepositoryProvider)),
);

final settingsUseCasesProvider = Provider<SettingsUseCases>(
  (ref) => SettingsUseCases(ref.watch(settingsRepositoryProvider)),
);

final entryUseCasesProvider = Provider<EntryUseCases>(
  (ref) => EntryUseCases(
    ref.watch(entriesRepositoryProvider),
    now: ref.watch(clockProvider),
  ),
);

final monthUseCasesProvider = Provider<MonthUseCases>(
  (ref) => MonthUseCases(
    ref.watch(entriesRepositoryProvider),
    ref.watch(ledgerRepositoryProvider),
    now: ref.watch(clockProvider),
  ),
);

final templateUseCasesProvider = Provider<TemplateUseCases>(
  (ref) => TemplateUseCases(ref.watch(templatesRepositoryProvider)),
);

final activityUseCasesProvider = Provider<ActivityUseCases>(
  (ref) => ActivityUseCases(ref.watch(activityRepositoryProvider)),
);

final summaryUseCasesProvider = Provider<SummaryUseCases>(
  (ref) => const SummaryUseCases(),
);

final holidayUseCasesProvider = Provider<HolidayUseCases>(
  (ref) => HolidayUseCases(ref.watch(holidaysRepositoryProvider)),
);
