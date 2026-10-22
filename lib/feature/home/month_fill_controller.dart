import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/entries_repository.dart';
import '../../core/data/providers.dart';
import '../../core/model/expense_template.dart';
import '../../core/model/year_month.dart';

/// 보고 있는 달에 고정 지출로 채울 것.
@immutable
class PlannedFill {
  const PlannedFill({
    required this.ledgerId,
    required this.month,
    required this.templates,
  });

  final String ledgerId;
  final YearMonth month;

  /// 그달에 아직 기본 월 지출이 없는 고정 지출.
  final List<ExpenseTemplate> templates;

  @override
  bool operator ==(Object other) =>
      other is PlannedFill &&
      other.ledgerId == ledgerId &&
      other.month == month &&
      listEquals(other.templates, templates);

  @override
  int get hashCode => Object.hash(ledgerId, month, Object.hashAll(templates));
}

/// 보고 있는 달에 고정 지출로 채울 것. 채울 것이 없거나 채울 수 없으면 null.
///
/// 보기 전용이면(규칙이 막는다), 자동으로 채우지 않는 달이면(지난 달·다음 달보다 먼 달),
/// 그달 항목이나 고정 지출을 아직 받지 못했으면 null이다. 달을 옮긴 직후에는 이전 달 항목으로 판단하지 않는다.
/// 값이 바뀔 때만 알리므로, 홈 틀이 듣다가 [MonthFillController.fill]로 넘긴다.
final plannedFillProvider = Provider<PlannedFill?>((ref) {
  final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
  final ledgerId = ref.watch(currentLedgerProvider.select((l) => l?.id));
  final month = ref.watch(selectedMonthProvider);
  if (!canWrite || ledgerId == null) return null;
  final thisMonth = YearMonth.of(ref.watch(clockProvider)());
  if (!fillsFromTemplates(month, thisMonth: thisMonth)) return null;
  if ((ref.watch(monthLedgerProvider), ref.watch(templatesProvider)) case (
    AsyncData(value: final ledger),
    AsyncData(value: final templates),
  )) {
    final missing = templatesMissingIn(ledger, templates);
    if (missing.isEmpty) return null;
    return PlannedFill(ledgerId: ledgerId, month: month, templates: missing);
  }
  return null;
});

/// 그달 기본 월 지출을 채우는 컨트롤러. 홈 틀이 떠 있는 동안 계속 살아 있게 autoDispose를 쓰지 않는다.
final monthFillControllerProvider = NotifierProvider<MonthFillController, bool>(
  MonthFillController.new,
);

/// 보고 있는 달에 빠진 기본 월 지출을 고정 지출로 채운다. 상태는 채우는 중인지다.
///
/// 실패는 화면에 알리지 않는다. 오프라인이면 다음에 그달을 다시 열 때 채우고, 그동안 그달은 빈 달로 보인다.
/// 채운 항목은 그달 구독([monthLedgerProvider])으로 요약·항목 탭에 들어온다.
class MonthFillController extends Notifier<bool> {
  @override
  bool build() => false;

  /// [fill]의 고정 지출로 그달 기본 월 지출을 만든다. 이미 있는 것은 저장소가 건너뛴다.
  ///
  /// 채우는 중에 들어온 호출은 무시한다. 끝난 뒤에도 빠진 것이 남아 있으면 [plannedFillProvider]가 다시 알린다.
  Future<void> fill(PlannedFill fill) async {
    final uid = ref.read(authUserProvider).value?.uid;
    if (state || uid == null) return;
    state = true;
    try {
      await ref
          .read(entriesRepositoryProvider)
          .fillPlanned(
            ledgerId: fill.ledgerId,
            month: fill.month,
            templates: fill.templates,
            uid: uid,
          );
    } on EntryWriteException catch (e) {
      debugPrint('그달 기본 월 지출을 채우지 못해 다음에 다시 열 때 채움: ${e.reason}');
    } catch (e) {
      debugPrint('그달 기본 월 지출 채우기 실패: $e');
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
