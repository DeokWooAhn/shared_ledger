import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repository/activity_repository.dart';
import '../../domain/repository/auth_repository.dart';
import '../../domain/repository/entries_repository.dart';
import '../../domain/repository/holidays_repository.dart';
import '../../domain/repository/ledger_repository.dart';
import '../../domain/repository/settings_repository.dart';
import '../../domain/repository/templates_repository.dart';

// 저장소 공급자. core는 구현(data)을 모르고 domain의 인터페이스만 내놓는다.
// 실제 구현은 앱 시작점이 ProviderScope(overrides:)로 넣고(lib/di.dart), 테스트는 가짜를 넣는다.
Never _notProvided(String name) =>
    throw UnimplementedError('$name은 앱 시작점(lib/di.dart)이나 테스트에서 넣는다');

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => _notProvided('authRepositoryProvider'),
);

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => _notProvided('ledgerRepositoryProvider'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => _notProvided('settingsRepositoryProvider'),
);

final entriesRepositoryProvider = Provider<EntriesRepository>(
  (ref) => _notProvided('entriesRepositoryProvider'),
);

final templatesRepositoryProvider = Provider<TemplatesRepository>(
  (ref) => _notProvided('templatesRepositoryProvider'),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => _notProvided('activityRepositoryProvider'),
);

final holidaysRepositoryProvider = Provider<HolidaysRepository>(
  (ref) => _notProvided('holidaysRepositoryProvider'),
);
