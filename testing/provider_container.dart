import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/providers/providers.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';

import 'fakes.dart';

/// 테스트의 '지금'. 날짜에 따라 결과가 흔들리지 않게 고정한다.
final testNow = DateTime(2026, 10, 15, 9);

/// 쓰기를 하는 가짜 저장소들이 같은 변경 기록 저장소에 기록을 남기게 잇는다. 넘기지 않은 것은 새로 만든다.
({
  FakeSettingsRepository settings,
  FakeEntriesRepository entries,
  FakeTemplatesRepository templates,
  FakeActivityRepository activity,
})
linkActivity({
  FakeLedgerRepository? ledgers,
  FakeSettingsRepository? settings,
  FakeEntriesRepository? entries,
  FakeTemplatesRepository? templates,
  FakeActivityRepository? activity,
}) {
  final linked = (
    settings: settings ?? FakeSettingsRepository(),
    entries: entries ?? FakeEntriesRepository(),
    templates: templates ?? FakeTemplatesRepository(),
    activity: activity ?? FakeActivityRepository(),
  );
  for (final fake in <LogsActivity>[
    ?ledgers,
    linked.settings,
    linked.entries,
    linked.templates,
  ]) {
    fake.activity ??= linked.activity;
  }
  // 항목을 더하면 가계부의 항목 있는 달 목록도 같이 바뀐다(실제는 같은 일괄 쓰기).
  linked.entries.ledgers ??= ledgers;
  return linked;
}

/// 가짜 저장소를 끼운 ProviderContainer. 테스트가 끝나면 정리된다.
ProviderContainer createContainer({
  FakeAuthRepository? auth,
  FakeLedgerRepository? ledgers,
  FakeSettingsRepository? settings,
  FakeEntriesRepository? entries,
  FakeTemplatesRepository? templates,
  FakeActivityRepository? activity,
  FakeHolidaysRepository? holidays,
  DateTime? now,
}) {
  final ledgerFake = ledgers ?? FakeLedgerRepository();
  final fakes = linkActivity(
    ledgers: ledgerFake,
    settings: settings,
    entries: entries,
    templates: templates,
    activity: activity,
  );
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      ledgerRepositoryProvider.overrideWithValue(ledgerFake),
      settingsRepositoryProvider.overrideWithValue(fakes.settings),
      entriesRepositoryProvider.overrideWithValue(fakes.entries),
      templatesRepositoryProvider.overrideWithValue(fakes.templates),
      activityRepositoryProvider.overrideWithValue(fakes.activity),
      holidaysRepositoryProvider.overrideWithValue(
        holidays ?? FakeHolidaysRepository(),
      ),
      clockProvider.overrideWithValue(() => now ?? testNow),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// 로그인 상태를 먼저 받아 둔다. Notifier가 `authUserProvider`의 값을 바로 읽을 수 있게 한다.
Future<void> loadSignedInUser(ProviderContainer container) async {
  container.listen(authUserProvider, (_, _) {});
  await container.read(authUserProvider.future);
}

/// 보고 있는 달의 항목을 받을 때까지 기다린다. 기다리는 동안 그달 구독을 살려 둔다.
Future<MonthLedger> selectedMonthLedger(ProviderContainer container) async {
  final month = container.read(selectedMonthProvider);
  final subscription = container.listen(
    monthLedgerOfProvider(month).future,
    (_, _) {},
  );
  try {
    return await subscription.read();
  } finally {
    subscription.close();
  }
}

/// autoDispose Notifier를 테스트 동안 살려 두고, 지나간 상태를 모두 기록한다.
List<S> recordStates<S>(
  ProviderContainer container,
  ProviderListenable<S> provider,
) {
  final states = <S>[];
  container.listen(provider, (_, next) => states.add(next));
  return states;
}
