import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/expense_template.dart';
import '../../domain/repository/entries_repository.dart';
import '../../domain/repository/templates_repository.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/year_month.dart';

/// 스낵바로 알릴 일회성 실패.
enum EntriesFailure {
  /// 꺼내기는 온라인에서만 된다.
  restoreOffline,

  /// 그사이 상대가 꺼냈거나 완전히 지웠다.
  restoreGone,
  restore,

  /// 그달 가계부 만들기(반복 설정으로 채우기)는 온라인에서만 된다.
  addMonthOffline,
  addMonth,
}

/// 항목 탭 상태. 목록은 공급자(monthLedgerProvider)에서 그리고, 여기에는 동작의 진행 상태만 둔다.
@immutable
class EntriesState {
  const EntriesState({
    this.restoring = false,
    this.addingMonth = false,
    this.failure,
  });

  /// 휴지통에서 꺼내는 중이다.
  final bool restoring;

  /// 달력에서 그달 가계부를 만드는 중이다.
  final bool addingMonth;

  bool get busy => restoring || addingMonth;

  /// 스낵바로 알릴 실패. 화면이 알린 뒤 [EntriesNotifier.failureShown]으로 끈다.
  final EntriesFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is EntriesState &&
      other.restoring == restoring &&
      other.addingMonth == addingMonth &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(restoring, addingMonth, failure);
}

final entriesNotifierProvider =
    NotifierProvider.autoDispose<EntriesNotifier, EntriesState>(
      EntriesNotifier.new,
    );

/// 항목 탭과 달력의 Notifier. 입력 화면에서 휴지통에 넣은 항목이나 그만한 고정 지출·고정 수입을 '되돌리기'로 되살리고,
/// 달력에서 가계부가 없는 달의 가계부를 만든다.
class EntriesNotifier extends Notifier<EntriesState> {
  @override
  EntriesState build() => const EntriesState();

  /// [month]의 [entry]를 휴지통에서 꺼낸다. 온라인에서만 된다.
  Future<void> restore(LedgerEntry entry, YearMonth month) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.busy || uid == null || ledgerId == null) return;
    state = const EntriesState(restoring: true);
    try {
      await ref
          .read(entryUseCasesProvider)
          .restoreEntry(
            ledgerId: ledgerId,
            month: month,
            entry: entry,
            uid: uid,
          );
      if (!ref.mounted) return;
      state = const EntriesState();
    } on EntryWriteException catch (e) {
      if (!ref.mounted) return;
      state = EntriesState(
        failure: switch (e.reason) {
          EntryWriteFailure.offline => EntriesFailure.restoreOffline,
          EntryWriteFailure.notFound => EntriesFailure.restoreGone,
        },
      );
    } catch (e) {
      debugPrint('항목 꺼내기 실패: $e');
      if (!ref.mounted) return;
      state = const EntriesState(failure: EntriesFailure.restore);
    }
  }

  /// 그만한 고정 지출·고정 수입을 되살린다. [template]은 그만하기 전의 반복 설정, [months]는 그때 휴지통에 넣은 달이다.
  /// 온라인에서만 되고, 실패는 꺼내기 실패와 같이 알린다.
  Future<void> resumeFixed(
    ExpenseTemplate template,
    List<YearMonth> months,
  ) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.busy || uid == null || ledgerId == null) return;
    state = const EntriesState(restoring: true);
    try {
      await ref
          .read(templateUseCasesProvider)
          .resumeFixedEntry(
            ledgerId: ledgerId,
            template: template,
            months: months,
            uid: uid,
          );
      if (!ref.mounted) return;
      state = const EntriesState();
    } on TemplateWriteException catch (e) {
      if (!ref.mounted) return;
      state = EntriesState(
        failure: switch (e.reason) {
          TemplateWriteFailure.offline => EntriesFailure.restoreOffline,
          TemplateWriteFailure.notFound => EntriesFailure.restoreGone,
        },
      );
    } catch (e) {
      debugPrint('반복 설정 되살리기 실패: $e');
      if (!ref.mounted) return;
      state = const EntriesState(failure: EntriesFailure.restore);
    }
  }

  /// [month] 가계부를 새로 만든다. 그달을 항목 있는 달 목록에 더하고, 반복 설정이 있으면 그달 고정 지출·고정 수입(지급 전·받기 전)로 채운다.
  /// 지난 달은 반복 설정으로 채우지 않고 달만 만든다(`AddMonthUseCase`).
  ///
  /// 달력에서 가계부가 없는 달에 항목을 넣으려 할 때 부른다. 한 트랜잭션이라 온라인에서만 되고, 만들었으면 true다.
  /// 실패는 [EntriesState.failure]로 알린다.
  Future<bool> addMonth(YearMonth month) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.busy || uid == null || ledgerId == null) return false;
    state = const EntriesState(addingMonth: true);
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
      if (ref.mounted) state = const EntriesState();
      return true;
    } on EntryWriteException catch (e) {
      if (!ref.mounted) return false;
      state = EntriesState(
        failure: switch (e.reason) {
          EntryWriteFailure.offline => EntriesFailure.addMonthOffline,
          EntryWriteFailure.notFound => EntriesFailure.addMonth,
        },
      );
      return false;
    } catch (e) {
      debugPrint('그달 가계부 만들기 실패: $e');
      if (!ref.mounted) return false;
      state = const EntriesState(failure: EntriesFailure.addMonth);
      return false;
    } finally {
      templates.close();
    }
  }

  /// 화면이 실패를 알린 뒤 부른다.
  void failureShown() => state = EntriesState(
    restoring: state.restoring,
    addingMonth: state.addingMonth,
  );
}
