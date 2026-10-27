import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecase/activity/activity_use_cases.dart';
import '../../domain/usecase/auth/auth_use_cases.dart';
import '../../domain/usecase/holiday/holiday_use_cases.dart';
import '../../domain/usecase/ledger/ledger_use_cases.dart';
import '../../domain/usecase/settings/settings_use_cases.dart';
import '../../domain/usecase/summary/summary_use_cases.dart';
import 'repositories.dart';

// UseCase 묶음 공급자. Notifier와 공급자(providers.dart)는 저장소 대신 이것을 읽는다.
// 묶음은 저장소 공급자로 만들어서, 테스트가 저장소 자리에 가짜를 넣으면 UseCase도 그 가짜를 쓴다.

final authUseCasesProvider = Provider<AuthUseCases>(
  (ref) => AuthUseCases(ref.watch(authRepositoryProvider)),
);

final ledgerUseCasesProvider = Provider<LedgerUseCases>(
  (ref) => LedgerUseCases(ref.watch(ledgerRepositoryProvider)),
);

final settingsUseCasesProvider = Provider<SettingsUseCases>(
  (ref) => SettingsUseCases(ref.watch(settingsRepositoryProvider)),
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
