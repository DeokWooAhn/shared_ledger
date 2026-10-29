import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/domain/repository/ledger_repository.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/invite.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/feature/ledger/ledger_start_notifier.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

const me = AuthUser(uid: 'me');
const partnerLedger = Ledger(
  id: 'l-partner',
  name: '바다네 가계부',
  ownerUid: 'partner',
);

const november = YearMonth(2026, 11);

void main() {
  group('가계부 만들기', () {
    test('이름의 앞뒤 공백을 빼고 나를 관리자로 만든다', () async {
      final ledgers = FakeLedgerRepository();
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );
      await loadSignedInUser(container);
      final states = recordStates(container, ledgerStartNotifierProvider);

      await container
          .read(ledgerStartNotifierProvider.notifier)
          .create(' 하늘바다 가계부 ', firstMonth: november);

      expect(ledgers.created, [
        (
          name: '하늘바다 가계부',
          ownerUid: 'me',
          ownerName: '나',
          firstMonth: november,
        ),
      ]);
      expect(states, [
        const LedgerStartState(pending: LedgerStartAction.create),
        const LedgerStartState(),
      ]);
    });

    test('이름표의 내 이름은 로그인 이름이고, 10자를 넘으면 자른다', () async {
      final ledgers = FakeLedgerRepository();
      final container = createContainer(
        auth: FakeAuthRepository(
          signedIn: const AuthUser(uid: 'me', displayName: ' 가나다라마바사아자차카 '),
        ),
        ledgers: ledgers,
      );
      await loadSignedInUser(container);
      recordStates(container, ledgerStartNotifierProvider);

      await container
          .read(ledgerStartNotifierProvider.notifier)
          .create('우리 가계부', firstMonth: november);

      expect(ledgers.created.single.ownerName, '가나다라마바사아자차');
    });

    test('만들기에 실패하면 스낵바로 알릴 실패를 켜고, 알린 뒤 끈다', () async {
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository()..failNextCreate = true,
      );
      await loadSignedInUser(container);
      recordStates(container, ledgerStartNotifierProvider);
      final notifier = container.read(ledgerStartNotifierProvider.notifier);

      await notifier.create('우리 가계부', firstMonth: november);
      expect(
        container.read(ledgerStartNotifierProvider).failure,
        LedgerStartFailure.create,
      );

      notifier.failureShown();
      expect(
        container.read(ledgerStartNotifierProvider),
        const LedgerStartState(),
      );
    });
  });

  group('초대 코드로 참여', () {
    test('모양이 다르면 서버에 묻지 않고 입력란 문제로 알린다', () async {
      final ledgers = FakeLedgerRepository();
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );
      await loadSignedInUser(container);
      recordStates(container, ledgerStartNotifierProvider);

      await container.read(ledgerStartNotifierProvider.notifier).join('abc');

      expect(ledgers.joins, isEmpty);
      expect(
        container.read(ledgerStartNotifierProvider),
        const LedgerStartState(codeProblem: InviteCodeProblem.malformed),
      );
    });

    test('정리한 코드로 참여한다', () async {
      final ledgers = FakeLedgerRepository()
        ..joinable['ABCDEFGH23'] = (
          ledger: partnerLedger,
          role: MemberRole.editor,
        );
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );
      await loadSignedInUser(container);
      recordStates(container, ledgerStartNotifierProvider);

      await container
          .read(ledgerStartNotifierProvider.notifier)
          .join('abcd-efgh 23');

      expect(ledgers.joins, [(code: 'ABCDEFGH23', uid: 'me')]);
      expect(
        container.read(ledgerStartNotifierProvider),
        const LedgerStartState(),
      );
    });

    test('참여 실패 이유를 입력란 문제로 바꾸고, 같은 코드로 다시 누르면 바로 다시 시도한다', () async {
      final ledgers = FakeLedgerRepository()
        ..joinable['ABCDEFGH23'] = (
          ledger: partnerLedger,
          role: MemberRole.editor,
        )
        ..nextJoinFailure = JoinFailure.expired;
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );
      await loadSignedInUser(container);
      recordStates(container, ledgerStartNotifierProvider);
      final notifier = container.read(ledgerStartNotifierProvider.notifier);

      await notifier.join('ABCDEFGH23');
      expect(
        container.read(ledgerStartNotifierProvider).codeProblem,
        InviteCodeProblem.expired,
      );

      await notifier.join('ABCDEFGH23');
      expect(ledgers.joins, hasLength(2));
      expect(container.read(ledgerStartNotifierProvider).codeProblem, isNull);
    });

    test('네트워크 오류처럼 예상하지 못한 실패는 스낵바로 알린다', () async {
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository()..failNextJoin = true,
      );
      await loadSignedInUser(container);
      recordStates(container, ledgerStartNotifierProvider);

      await container
          .read(ledgerStartNotifierProvider.notifier)
          .join('ABCDEFGH23');

      expect(
        container.read(ledgerStartNotifierProvider),
        const LedgerStartState(failure: LedgerStartFailure.join),
      );
    });

    test('코드를 고치면 이전 입력란 안내를 지운다', () async {
      final container = createContainer(auth: FakeAuthRepository(signedIn: me));
      await loadSignedInUser(container);
      recordStates(container, ledgerStartNotifierProvider);
      final notifier = container.read(ledgerStartNotifierProvider.notifier);

      await notifier.join('');
      expect(
        container.read(ledgerStartNotifierProvider).codeProblem,
        InviteCodeProblem.empty,
      );

      notifier.codeEdited();
      expect(container.read(ledgerStartNotifierProvider).codeProblem, isNull);
    });
  });
}
