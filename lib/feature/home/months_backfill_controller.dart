import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/entries_repository.dart';
import '../../core/data/providers.dart';
import '../../core/model/year_month.dart';

/// 항목 있는 달을 찾는 범위. 가계부를 만든 달 [monthsBackfillSpan]달 전부터 이번 달 [monthsBackfillSpan]달 뒤까지다.
const monthsBackfillSpan = 12;

/// 항목 있는 달 목록을 처음 모을 가계부와 살펴볼 달.
@immutable
class MonthsBackfill {
  const MonthsBackfill({required this.ledgerId, required this.months});

  final String ledgerId;

  /// 살펴볼 달. 오래된 것부터.
  final List<YearMonth> months;

  @override
  bool operator ==(Object other) =>
      other is MonthsBackfill &&
      other.ledgerId == ledgerId &&
      listEquals(other.months, months);

  @override
  int get hashCode => Object.hash(ledgerId, Object.hashAll(months));
}

/// [createdIn](가계부를 만든 달) [monthsBackfillSpan]달 전부터 [thisMonth] [monthsBackfillSpan]달 뒤까지의 달.
List<YearMonth> monthsToBackfill({
  required YearMonth createdIn,
  required YearMonth thisMonth,
}) {
  var month = createdIn;
  for (var i = 0; i < monthsBackfillSpan; i++) {
    month = month.previous;
  }
  var last = thisMonth;
  for (var i = 0; i < monthsBackfillSpan; i++) {
    last = last.next;
  }
  return [for (; month.compareTo(last) <= 0; month = month.next) month];
}

/// 지금 가계부의 항목 있는 달 목록을 모아야 하면 그 범위. 아니면 null.
///
/// 목록이 생기기 전에 만든 가계부([Ledger.months]가 null)이고 쓰기 권한이 있을 때만이다(보기 전용은 규칙이 막는다).
final monthsBackfillProvider = Provider<MonthsBackfill?>((ref) {
  final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
  final ledger = ref.watch(currentLedgerProvider);
  if (!canWrite || ledger == null || ledger.months != null) return null;
  final now = ref.watch(clockProvider)();
  return MonthsBackfill(
    ledgerId: ledger.id,
    months: monthsToBackfill(
      createdIn: YearMonth.of(ledger.createdAt ?? now),
      thisMonth: YearMonth.of(now),
    ),
  );
});

/// 목록을 모으는 컨트롤러. 홈 틀이 떠 있는 동안 살아 있으면서 [monthsBackfillProvider]를 듣는다.
final monthsBackfillControllerProvider =
    NotifierProvider<MonthsBackfillController, bool>(
      MonthsBackfillController.new,
    );

/// 목록이 생기기 전에 만든 가계부의 항목 있는 달을 한 번 찾아 가계부에 적는다. 상태는 모으는 중인지다.
///
/// 한 번 실행에 [monthsBackfillSpan]의 두 배 남짓한 달을 달마다 네 번씩 읽는다. 앱을 열 때마다 하지 않고,
/// 적고 나면 [Ledger.months]가 생겨 다시 하지 않는다. 실패(오프라인 등)는 알리지 않고 다음에 앱을 열 때 다시 한다.
/// 그동안 요약·항목 탭은 예전처럼 모든 달을 오간다.
class MonthsBackfillController extends Notifier<bool> {
  // 이번에 앱을 연 동안 이미 해 본 가계부. 실패해도 같은 세션에서는 다시 하지 않는다.
  final _tried = <String>{};

  @override
  bool build() {
    // 처음 값(이미 받아 둔 가계부)에도 바로 하도록 fireImmediately로 듣는다. 듣는 중에는 상태를 바꿀 수 없어서
    // 실제 일은 다음 차례로 미룬다.
    ref.listen(monthsBackfillProvider, (_, backfill) {
      if (backfill != null) unawaited(Future.microtask(() => run(backfill)));
    }, fireImmediately: true);
    return false;
  }

  /// [backfill] 범위에서 항목 있는 달을 찾아 가계부에 적는다. 같은 가계부는 한 번만 한다.
  Future<void> run(MonthsBackfill backfill) async {
    if (state || !_tried.add(backfill.ledgerId)) return;
    state = true;
    try {
      final found = await ref
          .read(entriesRepositoryProvider)
          .monthsWithEntries(backfill.ledgerId, backfill.months);
      if (!ref.mounted) return;
      await ref
          .read(ledgerRepositoryProvider)
          .recordMonths(ledgerId: backfill.ledgerId, months: found);
    } on EntryWriteException catch (e) {
      debugPrint('항목 있는 달을 모으지 못해 다음에 다시 모음: ${e.reason}');
    } catch (e) {
      debugPrint('항목 있는 달 모으기 실패: $e');
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
