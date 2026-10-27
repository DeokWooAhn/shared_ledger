import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/providers/providers.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/member.dart';
import 'package:shared_ledger/feature/settings/rename_notifier.dart';
import 'package:shared_ledger/feature/settings/setting_form.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

const me = AuthUser(uid: 'me');
const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');

/// 로그인하고 가계부 목록과 이름표까지 받은 컨테이너.
Future<ProviderContainer> ready({
  FakeLedgerRepository? ledgers,
  FakeSettingsRepository? settings,
}) async {
  final container = createContainer(
    auth: FakeAuthRepository(signedIn: me),
    ledgers: ledgers ?? FakeLedgerRepository([mine]),
    settings: settings,
  );
  await loadSignedInUser(container);
  container
    ..listen(myLedgersProvider, (_, _) {})
    ..listen(membersProvider, (_, _) {});
  await container.read(myLedgersProvider.future);
  await container.read(membersProvider.future);
  return container;
}

void main() {
  group('가계부 이름', () {
    test('바꾸면 저장소에 쓰고 끝난 상태가 된다', () async {
      final ledgers = FakeLedgerRepository([mine]);
      final container = await ready(ledgers: ledgers);
      const target = LedgerNameTarget();
      final states = recordStates(container, renameNotifierProvider(target));

      await container
          .read(renameNotifierProvider(target).notifier)
          .save(' 하늘바다 가계부 ');

      expect(ledgers.renames, [(ledgerId: 'l1', name: ' 하늘바다 가계부 ')]);
      expect(states, [
        const RenameState(saving: true),
        const RenameState(done: true),
      ]);
      // 바뀐 이름은 실제처럼 가계부 구독으로 조금 뒤에 들어온다.
      await pumpEventQueue();
      expect(container.read(currentLedgerProvider)?.name, '하늘바다 가계부');
    });

    test('비었거나 40자를 넘으면 문제로 알리고 쓰지 않는다', () async {
      final ledgers = FakeLedgerRepository([mine]);
      final container = await ready(ledgers: ledgers);
      const target = LedgerNameTarget();
      final notifier = container.read(renameNotifierProvider(target).notifier);
      recordStates(container, renameNotifierProvider(target));

      await notifier.save('  ');
      expect(
        container.read(renameNotifierProvider(target)).problem,
        NameProblem.missing,
      );
      await notifier.save('가' * 41);
      expect(
        container.read(renameNotifierProvider(target)).problem,
        NameProblem.tooLong,
      );
      expect(ledgers.renames, isEmpty);

      notifier.nameEdited();
      expect(container.read(renameNotifierProvider(target)).problem, isNull);
    });

    test('지금 이름과 같으면 쓰지 않고 끝낸다', () async {
      final ledgers = FakeLedgerRepository([mine]);
      final container = await ready(ledgers: ledgers);
      const target = LedgerNameTarget();
      recordStates(container, renameNotifierProvider(target));

      await container
          .read(renameNotifierProvider(target).notifier)
          .save('우리 가계부 ');

      expect(ledgers.renames, isEmpty);
      expect(container.read(renameNotifierProvider(target)).done, isTrue);
    });

    test('연결이 없으면 offline 실패를 시트에 남기고, 이름을 고치면 지운다', () async {
      final ledgers = FakeLedgerRepository([mine])..offline = true;
      final container = await ready(ledgers: ledgers);
      const target = LedgerNameTarget();
      final notifier = container.read(renameNotifierProvider(target).notifier);
      recordStates(container, renameNotifierProvider(target));

      await notifier.save('새 이름');

      expect(
        container.read(renameNotifierProvider(target)),
        const RenameState(failure: SettingFormFailure.offline),
      );
      notifier.nameEdited();
      expect(
        container.read(renameNotifierProvider(target)),
        const RenameState(),
      );
    });

    test('예상 못 한 오류는 save 실패로 알린다', () async {
      final ledgers = FakeLedgerRepository([mine])..failNextRename = true;
      final container = await ready(ledgers: ledgers);
      const target = LedgerNameTarget();
      recordStates(container, renameNotifierProvider(target));

      await container
          .read(renameNotifierProvider(target).notifier)
          .save('새 이름');

      expect(
        container.read(renameNotifierProvider(target)).failure,
        SettingFormFailure.save,
      );
    });
  });

  group('이름표 이름', () {
    test('바꾸면 그 자리 이름표에 쓴다', () async {
      final settings = FakeSettingsRepository();
      final container = await ready(settings: settings);
      const target = MemberNameTarget(MemberSlot.partner);
      recordStates(container, renameNotifierProvider(target));

      await container.read(renameNotifierProvider(target).notifier).save('파도');

      expect(settings.renamedMembers, [
        (ledgerId: 'l1', slot: MemberSlot.partner, name: '파도', uid: 'me'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(membersProvider).value, const [
        Member(slot: MemberSlot.owner, name: '하늘'),
        Member(slot: MemberSlot.partner, name: '파도'),
      ]);
    });

    test('10자를 넘으면 쓰지 않는다', () async {
      final settings = FakeSettingsRepository();
      final container = await ready(settings: settings);
      const target = MemberNameTarget(MemberSlot.owner);
      recordStates(container, renameNotifierProvider(target));

      await container
          .read(renameNotifierProvider(target).notifier)
          .save('가' * 11);

      expect(
        container.read(renameNotifierProvider(target)).problem,
        NameProblem.tooLong,
      );
      expect(settings.renamedMembers, isEmpty);
    });

    test('이름표가 없던 가계부는 화면의 역할 이름과 같아도 이름표를 새로 만든다', () async {
      final settings = FakeSettingsRepository(members: const []);
      final container = await ready(settings: settings);
      const target = MemberNameTarget(MemberSlot.owner);
      recordStates(container, renameNotifierProvider(target));

      await container.read(renameNotifierProvider(target).notifier).save('관리자');

      expect(settings.renamedMembers, hasLength(1));
      expect(settings.members, const [
        Member(slot: MemberSlot.owner, name: '관리자'),
      ]);
    });

    test('저장 중에 다시 눌러도 한 번만 쓴다', () async {
      final settings = FakeSettingsRepository();
      final container = await ready(settings: settings);
      const target = MemberNameTarget(MemberSlot.owner);
      final notifier = container.read(renameNotifierProvider(target).notifier);
      recordStates(container, renameNotifierProvider(target));

      await Future.wait([notifier.save('하늘빛'), notifier.save('하늘빛')]);

      expect(settings.renamedMembers, hasLength(1));
    });
  });
}
