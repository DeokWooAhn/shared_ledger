import '../../repository/ledger_repository.dart';
import 'create_invite_use_case.dart';
import 'create_ledger_use_case.dart';
import 'join_ledger_use_case.dart';
import 'rename_ledger_use_case.dart';
import 'select_current_ledger_use_case.dart';
import 'watch_my_ledgers_use_case.dart';

/// 가계부 UseCase 묶음. 가계부 공급자, 가계부 시작 화면, 초대·이름 바꾸기 시트가 읽는다.
class LedgerUseCases {
  LedgerUseCases(LedgerRepository ledgers)
    : watchMyLedgers = WatchMyLedgersUseCase(ledgers),
      selectCurrentLedger = const SelectCurrentLedgerUseCase(),
      createLedger = CreateLedgerUseCase(ledgers),
      joinLedger = JoinLedgerUseCase(ledgers),
      createInvite = CreateInviteUseCase(ledgers),
      renameLedger = RenameLedgerUseCase(ledgers);

  final WatchMyLedgersUseCase watchMyLedgers;
  final SelectCurrentLedgerUseCase selectCurrentLedger;
  final CreateLedgerUseCase createLedger;
  final JoinLedgerUseCase joinLedger;
  final CreateInviteUseCase createInvite;
  final RenameLedgerUseCase renameLedger;
}
