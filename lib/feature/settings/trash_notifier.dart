import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repository/entries_repository.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/trashed_entry.dart';
import '../../domain/model/year_month.dart';

/// 휴지통 항목에 하는 동작.
enum TrashAction { restore, purge }

/// 스낵바로 한 번 알릴 실패.
enum TrashFailure {
  /// 되살리기·완전 삭제는 온라인에서만 된다.
  offline,

  /// 그사이 상대가 되살렸거나 완전히 지웠다(자동 삭제 포함).
  gone,
  restore,
  purge,
}

/// 스낵바로 한 번 알릴 결과. 항목은 휴지통 목록에서 바로 빠져서 무엇을 했는지 알린다.
enum TrashNotice { restored, purged }

/// 휴지통 화면 상태. 목록은 공급자(monthLedgerProvider)에서 그리고, 여기에는 동작의 진행 상태만 둔다.
@immutable
class TrashState {
  const TrashState({this.pending, this.failure, this.notice});

  /// 진행 중인 동작과 그 항목 id. null이면 쉬는 중이다.
  final ({TrashAction action, String id})? pending;

  /// 화면이 알린 뒤 [TrashNotifier.failureShown]으로 끈다.
  final TrashFailure? failure;

  /// 화면이 알린 뒤 [TrashNotifier.noticeShown]으로 끈다.
  final TrashNotice? notice;

  bool get busy => pending != null;

  @override
  bool operator ==(Object other) =>
      other is TrashState &&
      other.pending == pending &&
      other.failure == failure &&
      other.notice == notice;

  @override
  int get hashCode => Object.hash(pending, failure, notice);
}

final trashNotifierProvider =
    NotifierProvider.autoDispose<TrashNotifier, TrashState>(TrashNotifier.new);

/// 휴지통 화면의 Notifier. 보고 있는 달의 휴지통 항목을 되살리거나 완전히 지운다. 둘 다 온라인에서만 된다.
class TrashNotifier extends Notifier<TrashState> {
  @override
  TrashState build() => const TrashState();

  /// [month]의 [entry]를 휴지통에서 꺼낸다. 그달 목록과 합계에 다시 들어간다.
  Future<void> restore(LedgerEntry entry, YearMonth month) =>
      _run(TrashAction.restore, entry, month);

  /// [month]의 [entry]를 완전히 지운다. 되살릴 수 없다.
  ///
  /// 반복 설정이 남아 있는 이번 달 이후의 고정 지출·고정 수입([staysInTrash])은 지우면 다시 만들어져서 지우지 않는다.
  /// 반복 설정 목록을 아직 받지 못했거나 못 받았으면 남아 있는지 알 수 없어서 고정 지출·고정 수입은 지우지 않는다.
  Future<void> purge(LedgerEntry entry, YearMonth month) {
    final templateIds = _templateIds;
    if (entry.kind.isFixed && templateIds == null) return Future.value();
    final known = templateIds ?? const <String>{};
    final thisMonth = YearMonth.of(ref.read(clockProvider)());
    if (staysInTrash(
      entry,
      month: month,
      thisMonth: thisMonth,
      templateIds: known,
    )) {
      return Future.value();
    }
    return _run(TrashAction.purge, entry, month, templateIds: known);
  }

  // 지금 있는 반복 설정 id. 목록을 아직 받지 못했거나 오류면 null이다. 휴지통 화면이 목록을 구독하고 있다.
  Set<String>? get _templateIds => switch (ref.read(templatesProvider)) {
    AsyncData(:final value) => {for (final template in value) template.id},
    _ => null,
  };

  Future<void> _run(
    TrashAction action,
    LedgerEntry entry,
    YearMonth month, {
    Set<String> templateIds = const {},
  }) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.busy || uid == null || ledgerId == null) return;
    state = TrashState(pending: (action: action, id: entry.id));
    final entries = ref.read(entryUseCasesProvider);
    try {
      var done = true;
      switch (action) {
        case TrashAction.restore:
          await entries.restoreEntry(
            ledgerId: ledgerId,
            month: month,
            entry: entry,
            uid: uid,
          );
        case TrashAction.purge:
          // 휴지통에 남길 항목은 purge에서 걸렀지만, 그사이 달이 바뀌었으면 UseCase가 다시 거른다.
          done = await entries.purgeEntry(
            ledgerId: ledgerId,
            month: month,
            entry: entry,
            templateIds: templateIds,
            uid: uid,
          );
      }
      if (!ref.mounted) return;
      state = done
          ? TrashState(
              notice: switch (action) {
                TrashAction.restore => TrashNotice.restored,
                TrashAction.purge => TrashNotice.purged,
              },
            )
          : const TrashState();
    } on EntryWriteException catch (e) {
      if (!ref.mounted) return;
      state = TrashState(
        failure: switch (e.reason) {
          EntryWriteFailure.offline => TrashFailure.offline,
          EntryWriteFailure.notFound => TrashFailure.gone,
        },
      );
    } catch (e) {
      debugPrint('휴지통 ${action.name} 실패: $e');
      if (!ref.mounted) return;
      state = TrashState(
        failure: switch (action) {
          TrashAction.restore => TrashFailure.restore,
          TrashAction.purge => TrashFailure.purge,
        },
      );
    }
  }

  /// 화면이 실패를 알린 뒤 부른다.
  void failureShown() =>
      state = TrashState(pending: state.pending, notice: state.notice);

  /// 화면이 결과를 알린 뒤 부른다.
  void noticeShown() =>
      state = TrashState(pending: state.pending, failure: state.failure);
}
