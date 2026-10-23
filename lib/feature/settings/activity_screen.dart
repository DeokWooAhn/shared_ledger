import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/model/activity.dart';
import '../../core/model/ledger.dart';
import '../../core/model/member.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/member_avatar.dart';
import '../../core/widget/tab_page.dart';
import 'activity_controller.dart';
import 'setting_list.dart';

/// 기록 줄에 붙이는 동작 표시. 모르는 동작(새 버전 앱이 남긴 것)은 '변경'이다.
String activityActionLabel(ActivityAction? action) => switch (action) {
  ActivityAction.entryCreate ||
  ActivityAction.templateCreate ||
  ActivityAction.categoryCreate ||
  ActivityAction.paymentMethodCreate => '추가',
  ActivityAction.entryUpdate ||
  ActivityAction.templateUpdate ||
  ActivityAction.categoryUpdate => '수정',
  ActivityAction.entryTrash => '휴지통',
  ActivityAction.entryRestore => '되살림',
  ActivityAction.entryPurge => '완전 삭제',
  ActivityAction.templateDelete => '삭제',
  ActivityAction.templateRestore => '되돌림',
  ActivityAction.ledgerRename ||
  ActivityAction.memberRename ||
  ActivityAction.paymentMethodRename => '이름 변경',
  ActivityAction.categoryHide || ActivityAction.paymentMethodHide => '숨김',
  ActivityAction.categoryShow || ActivityAction.paymentMethodShow => '다시 보임',
  null => '변경',
};

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 기록 묶음의 날짜 제목. 예: '오늘', '어제', '10월 21일 (화)', 해가 다르면 '2025년 12월 31일 (수)'
String activityDayLabel(DateTime day, {required DateTime today}) {
  final date = DateTime(day.year, day.month, day.day);
  final todayDate = DateTime(today.year, today.month, today.day);
  if (date == todayDate) return '오늘';
  if (date == DateTime(today.year, today.month, today.day - 1)) return '어제';
  final weekday = _weekdays[date.weekday - 1];
  final monthDay = '${date.month}월 ${date.day}일 ($weekday)';
  return date.year == today.year ? monthDay : '${date.year}년 $monthDay';
}

/// 기록 시각. 예: '오후 2:05', '오전 12:30'
String activityTimeLabel(DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '${at.hour < 12 ? '오전' : '오후'} $hour:$minute';
}

/// 변경 기록 화면. 설정 탭에서 들어온다(탭 막대는 그대로 보인다).
///
/// 두 사람이 항목·고정 지출·설정을 바꾼 기록을 최근 것부터 날짜별로 묶어 보여준다. 줄마다 누가(이름표)·언제·무엇을.
/// 최근 50건은 실시간으로 받고, 더 오래된 기록은 '더 보기'로 50건씩 읽는다. 보기 전용도 볼 수 있다.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activityControllerProvider);
    final controller = ref.read(activityControllerProvider.notifier);
    ref.listen(activityControllerProvider.select((s) => s.failure), (
      _,
      failure,
    ) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('activity-failure'),
          content: Text(
            keepAll(switch (failure) {
              ActivityFailure.loadMore => '더 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
            }),
          ),
        ),
      );
      controller.failureShown();
    });
    return TabPage(
      header: const SubPageTitle(
        '변경 기록',
        description: '두 사람이 항목과 설정을 바꾼 기록이에요. 1년이 지난 기록은 지워져요.',
      ),
      children: [
        switch (state.load) {
          ActivityLoad.loading => const SettingListLoading(),
          ActivityLoad.failed => const SettingListMessage(
            '변경 기록을 불러오지 못했어요. 잠시 후 다시 열어 주세요.',
          ),
          ActivityLoad.ready when state.items.isEmpty =>
            const SettingListMessage('아직 변경 기록이 없어요. 항목이나 설정을 바꾸면 여기에 남아요.'),
          ActivityLoad.ready => _ActivityContent(
            state: state,
            onMore: controller.loadMore,
          ),
        },
      ],
    );
  }
}

class _ActivityContent extends ConsumerWidget {
  const _ActivityContent({required this.state, required this.onMore});

  final ActivityState state;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(clockProvider)();
    final ledger = ref.watch(currentLedgerProvider);
    final members = ref.watch(membersProvider).value ?? const [];
    // 날짜별로 묶는다. 목록이 새것부터라 묶음도 새것부터다. 서버에 닿기 전 기록(시간 없음)은 방금 남긴 것이라 '오늘'에 둔다.
    final groups = <String, List<Activity>>{};
    for (final item in state.items) {
      final at = item.at?.toLocal();
      final title = activityDayLabel(at ?? today, today: today);
      (groups[title] ??= []).add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        for (final MapEntry(key: title, value: items) in groups.entries)
          SettingCard(
            key: ValueKey('activity-day-$title'),
            title: title,
            children: [
              for (final item in items)
                _ActivityRow(
                  key: ValueKey('activity-${item.id}'),
                  activity: item,
                  member: _memberOf(ledger, members, item.actorUid),
                ),
            ],
          ),
        if (state.hasMore)
          FilledButton.tonal(
            key: const Key('activity-more'),
            onPressed: state.loadingMore ? null : onMore,
            child: state.loadingMore
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('더 보기'),
          ),
      ],
    );
  }

  // 바꾼 사람의 이름표. 가계부에서 나간 사람이면 null이다.
  static Member? _memberOf(Ledger? ledger, List<Member> members, String uid) =>
      switch (ledger?.slotOf(uid)) {
        final slot? => memberIn(members, slot),
        null => null,
      };
}

/// 기록 한 줄: 바꾼 사람의 이름표와 이름, 동작 표시, 시각, 무엇을 바꿨는지.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.member, super.key});

  final Activity activity;

  /// null이면 가계부에서 나간 사람이다.
  final Member? member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final member = this.member;
    final at = activity.at?.toLocal();
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이름은 옆 글자로 읽으므로 동그라미는 화면 읽기 도구에서 뺀다.
            if (member == null)
              const _FormerMemberAvatar()
            else
              ExcludeSemantics(child: MemberAvatar(member: member, size: 36)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              member?.name ?? '나간 구성원',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SettingChip(activityActionLabel(activity.action)),
                          ],
                        ),
                      ),
                      Text(
                        at == null ? '올리는 중' : activityTimeLabel(at),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    keepAll(activity.summary),
                    key: const Key('activity-summary'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가계부에서 나간 사람의 동그라미. 이름표가 없어 사람 모양을 넣는다.
class _FormerMemberAvatar extends StatelessWidget {
  const _FormerMemberAvatar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outline),
      ),
      child: Icon(
        Icons.person_outline,
        size: 18,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
