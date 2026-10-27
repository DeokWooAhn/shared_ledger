import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/activity.dart';
import 'package:shared_ledger/domain/usecase/activity/activity_use_cases.dart';

import '../../../../testing/fakes.dart';

void main() {
  test('최근 변경 기록을 그 가계부 것으로 정한 개수만 지켜본다', () async {
    final activity = FakeActivityRepository();
    activity.log(
      const ActivityDraft(ActivityAction.entryCreate, '추가지출 · 점심 · 9,000원'),
      uid: 'me',
    );

    final items = await ActivityUseCases(
      activity,
    ).watchRecentActivity('l1').first;

    expect(items.single.summary, '추가지출 · 점심 · 9,000원');
    expect(activity.watched, ['l1']);
  });

  test("'더 보기'는 가장 오래된 기록 앞의 기록을 정한 개수만큼 읽는다", () async {
    final activity = FakeActivityRepository();
    final before = DateTime(2026, 10, 1);

    await ActivityUseCases(activity).loadOlderActivity('l1', before: before);

    expect(activity.loads, [
      (ledgerId: 'l1', before: before, limit: activityPageSize),
    ]);
  });
}
