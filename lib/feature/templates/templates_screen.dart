import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/model/category.dart';
import '../../domain/model/expense_template.dart';
import '../../domain/model/member.dart';
import '../../domain/model/payment_method.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/tab_page.dart';
import '../../domain/format/won.dart';
import 'template_form_notifier.dart';
import 'template_list.dart';
import 'templates_notifier.dart';

/// 고정 지출 입력 화면을 열고, 닫힐 때의 결과를 돌려준다. 화면 이동은 router.dart가 정해서 넘겨준다.
typedef OpenTemplateForm =
    Future<TemplateFormOutcome?> Function(
      BuildContext context,
      TemplateFormArgs args,
    );

String templatesFailureMessage(TemplatesFailure failure) => switch (failure) {
  TemplatesFailure.restoreOffline =>
    '연결되지 않아 되돌리지 못했어요. 인터넷에 연결된 뒤에 다시 추가해 주세요.',
  TemplatesFailure.restore => '되돌리지 못했어요. 잠시 후 다시 추가해 주세요.',
};

/// 고정 지출 탭(design/app/06). 매달 나가는 돈의 합계와, 분류마다 묶은 고정 지출을 보여준다.
///
/// 새 달(이번 달·다음 달)을 열면 이 목록으로 그달 기본 월 지출이 만들어진다(홈 틀의 MonthFillNotifier).
/// 줄을 누르면 입력 화면에서 고치거나 지운다. 보기 전용은 보기만 한다.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({required this.openForm, super.key});

  final OpenTemplateForm openForm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(templatesNotifierProvider.select((s) => s.failure), (
      _,
      failure,
    ) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keepAll(templatesFailureMessage(failure)))),
      );
      ref.read(templatesNotifierProvider.notifier).failureShown();
    });
    return TabPage(
      header: const TabTitle(
        '고정 지출',
        description: '새 달을 처음 열면 이 목록으로 그달 기본 지출이 만들어져요.',
      ),
      children: [_TemplatesBody(openForm: openForm)],
    );
  }
}

/// 고정 지출·분류·결제수단을 다 받으면 목록을, 아니면 불러오는 중이나 실패를 그린다.
class _TemplatesBody extends ConsumerWidget {
  const _TemplatesBody({required this.openForm});

  final OpenTemplateForm openForm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);
    final categories = ref.watch(categoriesProvider);
    final paymentMethods = ref.watch(paymentMethodsProvider);
    final values = <AsyncValue<Object>>[templates, categories, paymentMethods];
    if (values.any((value) => value.hasError)) return const _TemplatesFailed();
    if ((templates, categories, paymentMethods) case (
      AsyncData(value: final templates),
      AsyncData(value: final categories),
      AsyncData(value: final paymentMethods),
    )) {
      return _TemplatesContent(
        templates: templates,
        categories: categories,
        paymentMethods: paymentMethods,
        openForm: openForm,
      );
    }
    return const _TemplatesLoading();
  }
}

class _TemplatesContent extends ConsumerWidget {
  const _TemplatesContent({
    required this.templates,
    required this.categories,
    required this.paymentMethods,
    required this.openForm,
  });

  final List<ExpenseTemplate> templates;
  final List<Category> categories;
  final List<PaymentMethod> paymentMethods;
  final OpenTemplateForm openForm;

  // 고치기 화면을 열고, 지우고 돌아오면 '되돌리기'를 띄운다.
  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ExpenseTemplate template,
  ) async {
    // await 뒤에는 context가 사라졌을 수 있어서 미리 잡아 둔다.
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(templatesNotifierProvider.notifier);
    final outcome = await openForm(context, TemplateFormArgs.edit(template));
    if (outcome != TemplateFormOutcome.deleted) return;
    messenger.showSnackBar(
      SnackBar(
        key: const Key('template-deleted-snack-bar'),
        content: Text(keepAll('고정 지출을 지웠어요.')),
        // 동작이 있는 스낵바는 기본으로 계속 떠 있다. 되돌리기는 잠깐만 보여준다.
        persist: false,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          key: const Key('restore-template'),
          label: '되돌리기',
          onPressed: () => notifier.restore(template),
        ),
      ),
    );
  }

  // 모르는 자리 값(규칙이 owner·partner 말고는 막는다)은 관리자로 그린다.
  static MemberSlot _slotOf(String memberId) =>
      MemberSlot.values.asNameMap()[memberId] ?? MemberSlot.owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider).value ?? const [];
    final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
    final list = TemplateList.of(templates, categories: categories);
    final methods = {for (final method in paymentMethods) method.id: method};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        if (list.isEmpty)
          _EmptyTemplates(canWrite: canWrite)
        else ...[
          _TotalCard(list: list),
          for (final group in list.groups)
            _GroupCard(
              key: ValueKey('template-group-${group.key}'),
              title: group.title,
              children: [
                for (final template in group.templates)
                  _TemplateRow(
                    key: ValueKey('template-${template.id}'),
                    template: template,
                    memberName: memberIn(
                      members,
                      _slotOf(template.memberId),
                    ).name,
                    methodName:
                        methods[template.paymentMethodId]?.name ?? '결제수단 없음',
                    onTap: canWrite
                        ? () => _edit(context, ref, template)
                        : null,
                  ),
              ],
            ),
        ],
        if (canWrite)
          FilledButton.tonal(
            key: const Key('add-template'),
            // 새 고정 지출은 결과를 기다릴 일이 없다.
            onPressed: () =>
                unawaited(openForm(context, const TemplateFormArgs.add())),
            child: const Text('고정 지출 추가'),
          ),
      ],
    );
  }
}

/// 매달 나가는 돈 합계와 개수.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.list});

  final TemplateList list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = [
      '${list.count}개',
      if (list.unpricedCount > 0) '금액 미정 ${list.unpricedCount}개',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            '매달 나가는 돈',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
          Text(
            won(list.total),
            key: const Key('templates-total'),
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
          ),
          Text(
            count,
            key: const Key('templates-count'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// 분류 하나의 카드. 위에 분류 이름을 두고 줄 사이에 선을 긋는다.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: theme.colorScheme.outlineVariant,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            for (final (index, child) in children.indexed) ...[
              if (index > 0) divider,
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// 고정 지출 한 줄: 예정일 배지, 제목과 결제수단·누가, 금액.
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.memberName,
    required this.methodName,
    required this.onTap,
    super.key,
  });

  final ExpenseTemplate template;
  final String memberName;
  final String methodName;

  /// null이면 누를 수 없다(보기 전용).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final amount = template.amount;
    final day = dueDayLabel(template.dueDay);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          spacing: 12,
          children: [
            // 화면 읽기 도구에는 '매월 25일'로 읽힌다.
            Semantics(
              label: '매월 $day',
              excludeSemantics: true,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      day,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    template.title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$methodName · $memberName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (amount == null)
              Text(
                '금액 미정',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.textMuted,
                ),
              )
            else
              Text(
                won(amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 고정 지출이 하나도 없을 때의 안내.
class _EmptyTemplates extends StatelessWidget {
  const _EmptyTemplates({required this.canWrite});

  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('templates-empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          spacing: 6,
          children: [
            Text(
              keepAll('아직 고정 지출이 없어요.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (canWrite)
              Text(
                keepAll('관리비·보험처럼 매달 나가는 돈을 추가하면 이번 달과 다음 달 기본 지출이 만들어져요.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplatesLoading extends StatelessWidget {
  const _TemplatesLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('templates-loading'),
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _TemplatesFailed extends StatelessWidget {
  const _TemplatesFailed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('templates-failed'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Text(
          keepAll('고정 지출을 불러오지 못했어요. 잠시 후 다시 열어 주세요.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
