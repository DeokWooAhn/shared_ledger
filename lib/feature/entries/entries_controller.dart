import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/entries_repository.dart';
import '../../core/data/providers.dart';
import '../../core/model/ledger_entries.dart';
import '../../core/model/year_month.dart';

/// 스낵바로 알릴 일회성 실패.
enum EntriesFailure {
  /// 꺼내기는 온라인에서만 된다.
  restoreOffline,

  /// 그사이 상대가 꺼냈거나 완전히 지웠다.
  restoreGone,
  restore,
}

/// 항목 탭 상태. 목록은 공급자(monthLedgerProvider)에서 그리고, 여기에는 동작의 진행 상태만 둔다.
@immutable
class EntriesState {
  const EntriesState({this.restoring = false, this.failure});

  /// 휴지통에서 꺼내는 중이다.
  final bool restoring;

  /// 스낵바로 알릴 실패. 화면이 알린 뒤 [EntriesController.failureShown]으로 끈다.
  final EntriesFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is EntriesState &&
      other.restoring == restoring &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(restoring, failure);
}

final entriesControllerProvider =
    NotifierProvider.autoDispose<EntriesController, EntriesState>(
      EntriesController.new,
    );

/// 항목 탭의 컨트롤러. 입력 화면에서 휴지통에 넣은 항목을 '되돌리기'로 꺼낸다.
class EntriesController extends Notifier<EntriesState> {
  @override
  EntriesState build() => const EntriesState();

  /// [month]의 [entry]를 휴지통에서 꺼낸다. 온라인에서만 된다.
  Future<void> restore(LedgerEntry entry, YearMonth month) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.restoring || uid == null || ledgerId == null) return;
    state = const EntriesState(restoring: true);
    try {
      await ref
          .read(entriesRepositoryProvider)
          .restore(
            ledgerId: ledgerId,
            month: month,
            kind: entry.kind,
            id: entry.id,
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

  /// 화면이 실패를 알린 뒤 부른다.
  void failureShown() => state = EntriesState(restoring: state.restoring);
}
