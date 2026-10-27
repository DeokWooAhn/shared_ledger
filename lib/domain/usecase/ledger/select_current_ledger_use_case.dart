import '../../model/ledger.dart';

/// 내 가계부 목록에서 지금 볼 가계부를 고른다. 가계부가 없으면 null.
///
/// 커플 가계부라 보통 하나이고, 여럿이면 먼저 만든 것(목록의 맨 앞)을 쓴다.
class SelectCurrentLedgerUseCase {
  const SelectCurrentLedgerUseCase();

  Ledger? call(List<Ledger> ledgers) => ledgers.firstOrNull;
}
