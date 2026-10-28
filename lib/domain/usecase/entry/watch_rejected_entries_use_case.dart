import '../../repository/entries_repository.dart';

/// 서버가 받지 않은 새 항목을 지켜본다. 오프라인 추가는 서버를 기다리지 않아서 거부는 나중에 여기로 온다.
class WatchRejectedEntriesUseCase {
  const WatchRejectedEntriesUseCase(this._entries);

  final EntriesRepository _entries;

  Stream<RejectedEntry> call() => _entries.rejectedAdds;
}
