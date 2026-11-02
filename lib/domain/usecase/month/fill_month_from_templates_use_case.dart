import '../../repository/entries_repository.dart';
import 'plan_month_fill_use_case.dart';

/// [fill]의 반복 설정으로 그달 고정 지출·고정 수입(지급 전·받기 전)을 만들고 만든 개수를 돌려준다. 작성자는 [uid]다.
///
/// 이미 있는 것(휴지통 포함)은 저장소가 건너뛴다. 온라인에서만 되고, 연결이 없으면 [EntryWriteException]을 던진다.
class FillMonthFromTemplatesUseCase {
  const FillMonthFromTemplatesUseCase(this._entries);

  final EntriesRepository _entries;

  Future<int> call(PlannedFill fill, {required String uid}) =>
      _entries.fillPlanned(
        ledgerId: fill.ledgerId,
        month: fill.month,
        templates: fill.templates,
        uid: uid,
        recordMonth: fill.recordMonth,
      );
}
