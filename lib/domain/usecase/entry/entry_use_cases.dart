import '../../repository/entries_repository.dart';
import 'purge_entry_use_case.dart';
import 'restore_entry_use_case.dart';
import 'save_entry_use_case.dart';
import 'trash_entry_use_case.dart';
import 'watch_month_use_case.dart';
import 'watch_rejected_entries_use_case.dart';

/// 항목 UseCase 묶음. 그달 항목 공급자, 항목 입력 화면, 항목 탭, 휴지통이 읽는다.
class EntryUseCases {
  EntryUseCases(EntriesRepository entries, {required DateTime Function() now})
    : watchMonth = WatchMonthUseCase(entries),
      watchRejectedEntries = WatchRejectedEntriesUseCase(entries),
      saveEntry = SaveEntryUseCase(entries),
      trashEntry = TrashEntryUseCase(entries),
      restoreEntry = RestoreEntryUseCase(entries),
      purgeEntry = PurgeEntryUseCase(entries, now);

  final WatchMonthUseCase watchMonth;
  final WatchRejectedEntriesUseCase watchRejectedEntries;
  final SaveEntryUseCase saveEntry;
  final TrashEntryUseCase trashEntry;
  final RestoreEntryUseCase restoreEntry;
  final PurgeEntryUseCase purgeEntry;
}
