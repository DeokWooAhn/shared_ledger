import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/invite.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/name_problem.dart';
import 'package:shared_ledger/domain/repository/ledger_repository.dart';
import 'package:shared_ledger/domain/repository/settings_repository.dart';
import 'package:shared_ledger/domain/usecase/ledger/ledger_use_cases.dart';

import '../../../../testing/fakes.dart';

const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');
const partnerLedger = Ledger(
  id: 'l-partner',
  name: '바다네 가계부',
  ownerUid: 'partner',
);

void main() {
  group('내 가계부', () {
    test('내가 속한 가계부 목록을 지켜본다', () async {
      final useCases = LedgerUseCases(
        FakeLedgerRepository([mine, partnerLedger]),
      );

      expect(await useCases.watchMyLedgers('me').first, [mine]);
    });

    test('지금 볼 가계부는 목록의 맨 앞(먼저 만든 것)이고, 없으면 null이다', () {
      final useCases = LedgerUseCases(FakeLedgerRepository());

      expect(useCases.selectCurrentLedger(const [mine, partnerLedger]), mine);
      expect(useCases.selectCurrentLedger(const []), isNull);
    });
  });

  group('가계부 만들기', () {
    test('이름의 앞뒤 공백을 빼고, 이름표의 내 이름은 로그인 이름이다', () async {
      final ledgers = FakeLedgerRepository();
      final useCases = LedgerUseCases(ledgers);

      final id = await useCases.createLedger(
        name: ' 하늘바다 가계부 ',
        owner: const AuthUser(uid: 'me', displayName: ' 가나다라마바사아자차카 '),
      );

      expect(id, 'ledger-1');
      expect(ledgers.created, [
        (name: '하늘바다 가계부', ownerUid: 'me', ownerName: '가나다라마바사아자차'),
      ]);
    });

    test('로그인 이름이 없으면 이름표의 내 이름은 나다', () async {
      final ledgers = FakeLedgerRepository();

      await LedgerUseCases(ledgers).createLedger(
        name: '우리 가계부',
        owner: const AuthUser(uid: 'me'),
      );

      expect(ledgers.created.single.ownerName, '나');
    });
  });

  group('초대 코드로 참여', () {
    test('모양이 다르면 서버에 묻지 않고 문제를 돌려준다', () async {
      final ledgers = FakeLedgerRepository();
      final useCases = LedgerUseCases(ledgers);

      expect(
        await useCases.joinLedger(input: ' ', uid: 'me'),
        InviteCodeProblem.empty,
      );
      expect(
        await useCases.joinLedger(input: 'abc', uid: 'me'),
        InviteCodeProblem.malformed,
      );
      expect(ledgers.joins, isEmpty);
    });

    test('정리한 코드로 참여하고, 들어가면 null이다', () async {
      final ledgers = FakeLedgerRepository()
        ..joinable['ABCDEFGH23'] = (
          ledger: partnerLedger,
          role: MemberRole.editor,
        );

      final problem = await LedgerUseCases(
        ledgers,
      ).joinLedger(input: 'abcd-efgh 23', uid: 'me');

      expect(problem, isNull);
      expect(ledgers.joins, [(code: 'ABCDEFGH23', uid: 'me')]);
    });

    test('참여하지 못한 이유를 입력란 문제로 바꿔 돌려준다', () async {
      final ledgers = FakeLedgerRepository();
      final useCases = LedgerUseCases(ledgers);
      Future<InviteCodeProblem?> joinFailing(JoinFailure failure) {
        ledgers.nextJoinFailure = failure;
        return useCases.joinLedger(input: 'ABCDEFGH23', uid: 'me');
      }

      expect(
        await joinFailing(JoinFailure.notFound),
        InviteCodeProblem.notFound,
      );
      expect(await joinFailing(JoinFailure.expired), InviteCodeProblem.expired);
      expect(
        await joinFailing(JoinFailure.unavailable),
        InviteCodeProblem.unavailable,
      );
    });

    test('예상하지 못한 오류는 그대로 던진다', () async {
      final useCases = LedgerUseCases(
        FakeLedgerRepository()..failNextJoin = true,
      );

      await expectLater(
        useCases.joinLedger(input: 'ABCDEFGH23', uid: 'me'),
        throwsStateError,
      );
    });
  });

  test('고른 역할로 초대 코드를 만든다', () async {
    final ledgers = FakeLedgerRepository([mine]);

    final invite = await LedgerUseCases(
      ledgers,
    ).createInvite(ledgerId: 'l1', role: MemberRole.viewer, createdBy: 'me');

    expect(invite.role, MemberRole.viewer);
    expect(ledgers.invites, [
      (ledgerId: 'l1', role: MemberRole.viewer, createdBy: 'me'),
    ]);
  });

  group('가계부 이름 바꾸기', () {
    test('바꾸면 저장소에 쓴다', () async {
      final ledgers = FakeLedgerRepository([mine]);

      final problem = await LedgerUseCases(
        ledgers,
      ).renameLedger(ledger: mine, name: ' 하늘바다 가계부 ', uid: 'me');

      expect(problem, isNull);
      expect(ledgers.renames, [(ledgerId: 'l1', name: ' 하늘바다 가계부 ')]);
    });

    test('비었거나 40자를 넘으면 쓰지 않고 문제를 돌려준다', () async {
      final ledgers = FakeLedgerRepository([mine]);
      final useCases = LedgerUseCases(ledgers);

      expect(
        await useCases.renameLedger(ledger: mine, name: '  ', uid: 'me'),
        NameProblem.missing,
      );
      expect(
        await useCases.renameLedger(ledger: mine, name: '가' * 41, uid: 'me'),
        NameProblem.tooLong,
      );
      expect(ledgers.renames, isEmpty);
    });

    test('앞뒤 공백을 뺀 이름이 지금 이름과 같으면 쓰지 않는다', () async {
      final ledgers = FakeLedgerRepository([mine]);

      final problem = await LedgerUseCases(
        ledgers,
      ).renameLedger(ledger: mine, name: '우리 가계부 ', uid: 'me');

      expect(problem, isNull);
      expect(ledgers.renames, isEmpty);
    });

    test('연결이 없으면 저장소의 실패를 그대로 던진다', () async {
      final useCases = LedgerUseCases(
        FakeLedgerRepository([mine])..offline = true,
      );

      await expectLater(
        useCases.renameLedger(ledger: mine, name: '새 이름', uid: 'me'),
        throwsA(
          isA<SettingsWriteException>().having(
            (e) => e.reason,
            'reason',
            SettingsWriteFailure.offline,
          ),
        ),
      );
    });
  });
}
