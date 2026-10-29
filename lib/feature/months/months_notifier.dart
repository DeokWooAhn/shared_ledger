import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/model/year_month.dart';
import '../../domain/repository/entries_repository.dart';

/// 스낵바로 알릴 일회성 실패.
enum MonthsFailure {
  /// 가계부 추가(반복 설정으로 채우기)는 온라인에서만 된다.
  addOffline,
  add,
}

/// 가계부 탭 상태. 달 목록은 공급자(ledgerMonthsProvider)에서 그리고, 여기에는 추가 중인지와 실패만 둔다.
@immutable
class MonthsState {
  const MonthsState({this.adding = false, this.failure});

  /// 가계부를 추가하는 중이다.
  final bool adding;

  /// 스낵바로 알릴 실패. 화면이 알린 뒤 [MonthsNotifier.failureShown]으로 끈다.
  final MonthsFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is MonthsState &&
      other.adding == adding &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(adding, failure);
}

final monthsNotifierProvider =
    NotifierProvider.autoDispose<MonthsNotifier, MonthsState>(
      MonthsNotifier.new,
    );

/// 가계부 탭의 Notifier. 고른 달의 가계부를 추가한다.
class MonthsNotifier extends Notifier<MonthsState> {
  @override
  MonthsState build() => const MonthsState();

  /// [month] 가계부를 추가한다. 그달을 가계부의 달 목록에 더하고, 이번 달 이후면 반복 설정으로 그달 고정 지출(지급 전)을 채운다.
  /// 지난 달은 채우지 않고 달만 만든다(`AddMonthUseCase`). 한 트랜잭션이라 온라인에서만 되고, 추가했으면 true다.
  /// 실패는 [MonthsState.failure]로 알린다.
  Future<bool> add(YearMonth month) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.adding || uid == null || ledgerId == null) return false;
    state = const MonthsState(adding: true);
    // 아무도 듣지 않는 공급자는 멈춰 있어 값을 기다리면 끝나지 않는다. 받는 동안 직접 듣는다.
    final templates = ref.listen(templatesProvider.future, (_, _) {});
    try {
      // 반복 설정은 채우는 달일 때만 기다린다.
      await ref
          .read(monthUseCasesProvider)
          .addMonth(
            ledgerId: ledgerId,
            month: month,
            uid: uid,
            templates: templates.read,
          );
      if (ref.mounted) state = const MonthsState();
      return true;
    } on EntryWriteException catch (e) {
      if (!ref.mounted) return false;
      state = MonthsState(
        failure: switch (e.reason) {
          EntryWriteFailure.offline => MonthsFailure.addOffline,
          EntryWriteFailure.notFound => MonthsFailure.add,
        },
      );
      return false;
    } catch (e) {
      debugPrint('가계부 추가 실패: $e');
      if (!ref.mounted) return false;
      state = const MonthsState(failure: MonthsFailure.add);
      return false;
    } finally {
      templates.close();
    }
  }

  /// 화면이 실패를 알린 뒤 부른다.
  void failureShown() => state = MonthsState(adding: state.adding);
}
