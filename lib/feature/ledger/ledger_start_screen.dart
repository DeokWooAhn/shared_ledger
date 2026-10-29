import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/invite.dart';
import '../../domain/model/ledger.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/sign_out.dart';
import 'ledger_start_notifier.dart';

/// 가계부 이름 검사. 통과하면 null, 아니면 안내 문구.
String? validateLedgerName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return '가계부 이름을 입력해 주세요.';
  if (name.length > ledgerNameMaxLength) {
    return '가계부 이름은 $ledgerNameMaxLength자까지 쓸 수 있어요.';
  }
  return null;
}

/// 초대 코드 입력란 아래에 보여 줄 문구.
String inviteCodeProblemMessage(InviteCodeProblem problem) => switch (problem) {
  InviteCodeProblem.empty => '초대 코드를 입력해 주세요.',
  InviteCodeProblem.malformed => '초대 코드를 다시 확인해 주세요.',
  InviteCodeProblem.notFound => '초대 코드를 찾을 수 없어요. 코드를 다시 확인해 주세요.',
  InviteCodeProblem.expired => '기간이 지난 초대 코드예요. 새 코드를 받아 주세요.',
  InviteCodeProblem.unavailable => '이 가계부에는 더 들어갈 수 없어요. 초대한 사람에게 확인해 주세요.',
};

String ledgerStartFailureMessage(LedgerStartFailure failure) =>
    switch (failure) {
      LedgerStartFailure.create => '가계부를 만들지 못했어요. 잠시 후 다시 시도해 주세요.',
      LedgerStartFailure.join => '입장하지 못했어요. 잠시 후 다시 시도해 주세요.',
    };

/// 만들기·입장 화면이 같이 쓰는 실패 알림. 스낵바로 알린 뒤 [LedgerStartNotifier.failureShown]으로 끈다.
void listenLedgerStartFailure(BuildContext context, WidgetRef ref) => ref
    .listen(ledgerStartNotifierProvider.select((s) => s.failure), (_, failure) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keepAll(ledgerStartFailureMessage(failure)))),
      );
      ref.read(ledgerStartNotifierProvider.notifier).failureShown();
    });

/// 가계부 시작 화면(design/app/02). 가계부가 없으면 로그인 뒤 여기로 온다.
///
/// '가계부 만들기'와 '초대 코드로 입장' 두 길만 크게 보여 주고, 고르면 각자의 화면에서 입력한다(02a·02b).
/// 둘 중 하나만 하면 된다. 만든 사람이 관리자가 되고, 초대 코드로 들어온 사람은 초대에 정해진 역할을 받는다.
/// 화면 이동은 router.dart가 정해서 넘겨준다.
class LedgerStartScreen extends ConsumerWidget {
  const LedgerStartScreen({
    required this.openCreate,
    required this.openJoin,
    super.key,
  });

  final void Function(BuildContext context) openCreate;
  final void Function(BuildContext context) openJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            // 두 길이 남은 높이를 나눠 크게 차지하고, 높이가 모자라면(가로 화면) 스크롤한다.
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  keepAll('함께 쓸 가계부를 정해요'),
                                  style: theme.textTheme.headlineSmall,
                                ),
                              ),
                              Text(
                                keepAll(
                                  '한 사람이 가계부를 만들고, 다른 한 사람은 초대 코드로 들어와요.',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _ChoicePanel(
                            key: const Key('start-create'),
                            icon: Icons.add,
                            title: '가계부 만들기',
                            description: '새 가계부를 만들고 상대를 초대해요',
                            background: colors.hero,
                            foreground: colors.onHero,
                            subtle: colors.heroSub,
                            iconBackground: colors.onHero.withValues(
                              alpha: 0.15,
                            ),
                            onTap: () => openCreate(context),
                          ),
                        ),
                        Expanded(
                          child: _ChoicePanel(
                            key: const Key('start-join'),
                            icon: Icons.confirmation_number_outlined,
                            title: '초대 코드로 입장',
                            description: '상대가 만든 가계부에 코드로 들어가요',
                            background:
                                theme.colorScheme.surfaceContainerLowest,
                            foreground: theme.colorScheme.onSurface,
                            subtle: theme.colorScheme.onSurfaceVariant,
                            iconBackground: theme.colorScheme.primaryContainer,
                            iconColor: colors.accentText,
                            onTap: () => openJoin(context),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            key: const Key('sign-out'),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () => signOutWithFeedback(context, ref),
                            child: const Text('로그아웃'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 가계부 시작의 한 길. 위에 아이콘, 아래에 이름·설명·화살표를 두고 영역 전체를 누른다.
class _ChoicePanel extends StatelessWidget {
  const _ChoicePanel({
    required this.icon,
    required this.title,
    required this.description,
    required this.background,
    required this.foreground,
    required this.subtle,
    required this.iconBackground,
    required this.onTap,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color background;
  final Color foreground;
  final Color subtle;
  final Color iconBackground;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    return Semantics(
      button: true,
      child: Material(
        color: background,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 160),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: iconBackground,
                      child: Icon(icon, color: iconColor ?? foreground),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6,
                          children: [
                            Text(
                              keepAll(title),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: foreground,
                              ),
                            ),
                            Text(
                              keepAll(description),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: subtle,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ExcludeSemantics(
                        child: Icon(Icons.arrow_forward, color: foreground),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
