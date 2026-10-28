import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/providers/providers.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/domain/usecase/month/plan_month_fill_use_case.dart';
import 'package:shared_ledger/feature/home/month_fill_notifier.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

const me = AuthUser(uid: 'me');
const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');
const october = YearMonth(2026, 10);

const rent = ExpenseTemplate(
  id: 'rent',
  title: '관리비',
  categoryId: 'c-spending',
  paymentMethodId: 'p-account',
  memberId: 'partner',
  dueDay: lastDueDay,
);
const insurance = ExpenseTemplate(
  id: 'insurance',
  title: '보험',
  amount: 154000,
  categoryId: 'c-spending',
  paymentMethodId: 'p-account',
  memberId: 'owner',
  dueDay: 15,
);

/// 로그인하고 가계부 목록·그달 항목·고정 지출까지 받은 컨테이너. [plannedFillProvider]를 듣고 있다.
Future<ProviderContainer> ready({
  FakeEntriesRepository? entries,
  List<ExpenseTemplate> templates = const [rent, insurance],
  Ledger ledger = mine,
}) async {
  final container = createContainer(
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([ledger]),
    entries: entries,
    templates: FakeTemplatesRepository(templates),
  );
  await loadSignedInUser(container);
  container.listen(myLedgersProvider, (_, _) {});
  await container.read(myLedgersProvider.future);
  listenAll(container);
  await loaded(container);
  return container;
}

/// 탭 화면처럼 그달 항목과 고정 지출을 듣고, 홈 틀처럼 채울 것을 듣는다.
/// 채울 것이 일찍 null로 끝나는 경우(보기 전용, 지난 달)에도 항목 구독이 멈추지 않게 한다.
void listenAll(ProviderContainer container) {
  container
    ..listen(monthLedgerProvider, (_, _) {})
    ..listen(templatesProvider, (_, _) {})
    ..listen(plannedFillProvider, (_, _) {});
}

/// 보는 달의 항목과 고정 지출을 받을 때까지 기다린다.
Future<void> loaded(ProviderContainer container) async {
  await selectedMonthLedger(container);
  await container.read(templatesProvider.future);
}

void main() {
  group('채울 것(plannedFillProvider)', () {
    test('이번 달에 아직 없는 고정 지출을 채울 것으로 낸다', () async {
      final container = await ready();

      expect(
        container.read(plannedFillProvider),
        const PlannedFill(
          ledgerId: 'l1',
          month: october,
          templates: [rent, insurance],
        ),
      );
    });

    test('이미 있거나 휴지통에 넣은 기본 월 지출의 고정 지출은 빼고, 다 있으면 null이다', () async {
      final entries = FakeEntriesRepository({
        october: const MonthLedger(plannedIds: {'rent'}),
      });
      final container = await ready(entries: entries);

      expect(container.read(plannedFillProvider)?.templates, [insurance]);

      entries.put(
        october,
        const MonthLedger(plannedIds: {'rent', 'insurance'}),
      );
      await selectedMonthLedger(container);
      await pumpEventQueue();

      expect(container.read(plannedFillProvider), isNull);
    });

    test('다음 달도 채우고, 지난 달과 다다음 달은 채우지 않는다', () async {
      final container = await ready();
      final month = container.read(selectedMonthProvider.notifier);

      month.next();
      await loaded(container);
      expect(
        container.read(plannedFillProvider)?.month,
        const YearMonth(2026, 11),
      );

      month.next();
      await loaded(container);
      expect(container.read(plannedFillProvider), isNull);

      month
        ..previous()
        ..previous()
        ..previous();
      await loaded(container);
      expect(container.read(selectedMonthProvider), const YearMonth(2026, 9));
      expect(container.read(plannedFillProvider), isNull);
    });

    test('달 목록에 없는 다음 달은 보기만 해서는 채우지 않고, 목록에 있으면 채운다', () async {
      Future<PlannedFill?> nextMonthFill(Set<YearMonth> months) async {
        final container = await ready(
          ledger: Ledger(
            id: 'l1',
            name: '우리 가계부',
            ownerUid: 'me',
            months: months,
          ),
        );
        container.read(selectedMonthProvider.notifier).next();
        await loaded(container);
        return container.read(plannedFillProvider);
      }

      // 달력으로 11월을 지나가기만 해도 11월이 생기지 않게 한다.
      expect(await nextMonthFill({october}), isNull);
      expect(
        (await nextMonthFill({october, const YearMonth(2026, 11)}))?.month,
        const YearMonth(2026, 11),
      );
    });

    test('보기 전용은 채우지 않는다(규칙이 막는다)', () async {
      final container = await ready(
        ledger: const Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'partner-uid',
          roles: {'me': MemberRole.viewer},
        ),
      );

      expect(container.read(plannedFillProvider), isNull);
    });

    test('고정 지출이 없으면 채울 것이 없다', () async {
      final container = await ready(templates: const []);

      expect(container.read(plannedFillProvider), isNull);
    });

    test('고정 지출을 더하면 이번 달에 그것만 채울 것으로 낸다', () async {
      final entries = FakeEntriesRepository({
        october: const MonthLedger(plannedIds: {'rent'}),
      });
      final templates = FakeTemplatesRepository(const [rent]);
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([mine]),
        entries: entries,
        templates: templates,
      );
      await loadSignedInUser(container);
      container.listen(myLedgersProvider, (_, _) {});
      await container.read(myLedgersProvider.future);
      listenAll(container);
      await loaded(container);
      expect(container.read(plannedFillProvider), isNull);

      templates.put(const [rent, insurance]);
      await pumpEventQueue();

      expect(container.read(plannedFillProvider)?.templates, [insurance]);
    });
  });

  group('채우기(MonthFillNotifier)', () {
    test('빠진 고정 지출로 그달 기본 월 지출을 만들고, 다 채우면 채울 것이 없어진다', () async {
      final entries = FakeEntriesRepository();
      final container = await ready(entries: entries);
      final states = recordStates(container, monthFillNotifierProvider);
      final fill = container.read(plannedFillProvider)!;

      await container.read(monthFillNotifierProvider.notifier).fill(fill);
      await pumpEventQueue();

      expect(states, [true, false]);
      expect(entries.filled.single.uid, 'me');
      expect(entries.filled.single.templateIds, ['rent', 'insurance']);
      final planned = entries.monthOf(october).plannedExpenses;
      expect(planned.map((e) => e.id), ['rent', 'insurance']);
      expect(planned.first.dueOn, DateTime(2026, 10, 31));
      expect(planned.first.isPaid, isFalse);
      expect(container.read(plannedFillProvider), isNull);
    });

    test('달 목록에 없는 달을 채우면 그달을 달 목록에 같이 더한다', () async {
      final entries = FakeEntriesRepository();
      final container = await ready(
        entries: entries,
        ledger: Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'me',
          months: {const YearMonth(2026, 9)},
        ),
      );
      final fill = container.read(plannedFillProvider);
      expect(fill?.recordMonth, isTrue);

      await container.read(monthFillNotifierProvider.notifier).fill(fill!);
      await pumpEventQueue();

      expect(entries.recordedMonths, [october]);
      expect(container.read(currentLedgerProvider)?.months, contains(october));
    });

    test('달 목록을 아직 모으지 않은 가계부면 채워도 달 목록에 더하지 않는다', () async {
      final entries = FakeEntriesRepository();
      final container = await ready(entries: entries);
      final fill = container.read(plannedFillProvider);
      expect(fill?.recordMonth, isFalse);

      await container.read(monthFillNotifierProvider.notifier).fill(fill!);

      expect(entries.filled, hasLength(1));
      expect(entries.recordedMonths, isEmpty);
    });

    test('채우는 중에 같은 요청으로 다시 불러도 한 번만 채운다', () async {
      final entries = FakeEntriesRepository();
      final container = await ready(entries: entries);
      recordStates(container, monthFillNotifierProvider);
      final fill = container.read(plannedFillProvider)!;
      final notifier = container.read(monthFillNotifierProvider.notifier);

      await Future.wait([notifier.fill(fill), notifier.fill(fill)]);

      expect(entries.filled, hasLength(1));
    });

    test('채우는 중에 다음 달로 옮기면 끝난 뒤 다음 달도 채운다', () async {
      // 이번 달을 채우는 동안 다음 달 요청이 오고, 그 뒤로 채울 것이 다시 바뀌지 않는 경우.
      final entries = FakeEntriesRepository();
      final container = await ready(entries: entries);
      final states = recordStates(container, monthFillNotifierProvider);
      final thisMonth = container.read(plannedFillProvider)!;
      const nextMonth = PlannedFill(
        ledgerId: 'l1',
        month: YearMonth(2026, 11),
        templates: [rent, insurance],
      );
      final notifier = container.read(monthFillNotifierProvider.notifier);

      await Future.wait([notifier.fill(thisMonth), notifier.fill(nextMonth)]);

      expect(entries.filled.map((f) => f.month), [
        october,
        const YearMonth(2026, 11),
      ]);
      expect(
        entries.monthOf(const YearMonth(2026, 11)).plannedExpenses,
        hasLength(2),
      );
      expect(states, [true, false]);
    });

    test('채우는 중에 여러 요청이 오면 끝난 뒤 가장 최근 것만 채운다', () async {
      final entries = FakeEntriesRepository();
      final container = await ready(entries: entries);
      recordStates(container, monthFillNotifierProvider);
      final thisMonth = container.read(plannedFillProvider)!;
      PlannedFill fillOf(YearMonth month) =>
          PlannedFill(ledgerId: 'l1', month: month, templates: const [rent]);
      final notifier = container.read(monthFillNotifierProvider.notifier);

      await Future.wait([
        notifier.fill(thisMonth),
        notifier.fill(fillOf(const YearMonth(2026, 11))),
        notifier.fill(fillOf(const YearMonth(2026, 12))),
      ]);

      expect(entries.filled.map((f) => f.month), [
        october,
        const YearMonth(2026, 12),
      ]);
    });

    test('오프라인이면 만들지 못해도 알리지 않고 다음에 다시 채울 수 있다', () async {
      final entries = FakeEntriesRepository()..offline = true;
      final container = await ready(entries: entries);
      final states = recordStates(container, monthFillNotifierProvider);
      final fill = container.read(plannedFillProvider)!;
      final notifier = container.read(monthFillNotifierProvider.notifier);

      await notifier.fill(fill);

      expect(states, [true, false]);
      expect(entries.monthOf(october).plannedExpenses, isEmpty);
      expect(container.read(plannedFillProvider), fill);

      entries.offline = false;
      await notifier.fill(fill);
      expect(entries.monthOf(october).plannedExpenses.map((e) => e.id), [
        'rent',
        'insurance',
      ]);
    });

    test('예상 못 한 오류도 삼키고 채우는 중 상태를 푼다', () async {
      final entries = FakeEntriesRepository()..failNextWrite = true;
      final container = await ready(entries: entries);
      final states = recordStates(container, monthFillNotifierProvider);

      await container
          .read(monthFillNotifierProvider.notifier)
          .fill(container.read(plannedFillProvider)!);

      expect(states, [true, false]);
      expect(entries.filled, isEmpty);
    });

    test('이미 있는 기본 월 지출은 저장소가 건너뛰어 덮어쓰지 않는다', () async {
      // 그사이 상대가 먼저 만들고 금액을 고친 관리비.
      const edited = PlannedExpense(
        id: 'rent',
        categoryId: 'c-spending',
        memberId: 'partner',
        title: '관리비',
        paymentMethodId: 'p-account',
        amount: 210000,
      );
      final entries = FakeEntriesRepository();
      final container = await ready(entries: entries);
      final fill = container.read(plannedFillProvider)!;
      entries.put(october, const MonthLedger(plannedExpenses: [edited]));

      await container.read(monthFillNotifierProvider.notifier).fill(fill);

      expect(entries.filled.single.created, 1);
      final planned = entries.monthOf(october).plannedExpenses;
      expect(planned.firstWhere((e) => e.id == 'rent').amount, 210000);
      expect(planned.map((e) => e.id), ['rent', 'insurance']);
    });
  });
}
