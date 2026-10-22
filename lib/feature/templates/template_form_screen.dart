import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/model/expense_template.dart';
import '../../core/model/ledger_entries.dart';
import '../../core/model/member.dart';
import '../../core/model/payment_method.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/form_parts.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/labeled_field.dart';
import '../../core/widget/won_input.dart';
import 'template_form_controller.dart';
import 'template_list.dart';

/// 입력란 아래에 보여 줄 문구.
String templateProblemMessage(TemplateProblem problem) => switch (problem) {
  TemplateProblem.titleMissing => '내용을 입력해 주세요.',
  TemplateProblem.titleTooLong => '내용은 $entryTitleMaxLength자까지 쓸 수 있어요.',
  TemplateProblem.categoryMissing => '분류를 골라 주세요.',
  TemplateProblem.paymentMethodMissing => '결제수단을 골라 주세요.',
  TemplateProblem.dueDayMissing => '예정일을 골라 주세요.',
};

String templateFormFailureMessage(TemplateFormFailure failure) =>
    switch (failure) {
      TemplateFormFailure.offline =>
        '인터넷에 연결된 뒤에 다시 시도해 주세요. 고정 지출은 연결돼 있을 때만 바꿀 수 있어요.',
      TemplateFormFailure.gone => '그사이 지워진 고정 지출이에요.',
      TemplateFormFailure.save => '저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
      TemplateFormFailure.delete => '지우지 못했어요. 잠시 후 다시 시도해 주세요.',
    };

/// 고정 지출 입력·수정 화면. 항목 입력(design/app/05)처럼 X로 닫는 전체 화면이고, 넓은 화면에서는 가운데 560폭으로 둔다.
///
/// 금액(비우면 금액 미정)·내용·누가·분류·결제수단·매월 예정일을 받는다.
/// 저장하거나 지우면 [TemplateFormOutcome]을 돌려주며 닫힌다.
class TemplateFormScreen extends ConsumerStatefulWidget {
  const TemplateFormScreen({required this.args, super.key});

  final TemplateFormArgs args;

  @override
  ConsumerState<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends ConsumerState<TemplateFormScreen> {
  // 입력란 글자는 화면에만 필요한 상태라 위젯이 갖고, 저장할 때 컨트롤러에 넘긴다.
  late final TextEditingController _amount;
  late final TextEditingController _title;

  @override
  void initState() {
    super.initState();
    final template = widget.args.template;
    _amount = TextEditingController(text: wonInputText(template?.amount));
    _title = TextEditingController(text: template?.title ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  void _save() => ref
      .read(templateFormControllerProvider(widget.args).notifier)
      .save(amount: _amount.text, title: _title.text);

  Future<void> _pickDueDay(int? selected) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DueDaySheet(selected: selected),
    );
    if (picked == null || !mounted) return;
    ref
        .read(templateFormControllerProvider(widget.args).notifier)
        .selectDueDay(picked);
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final isEdit = args.template != null;
    final provider = templateFormControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider.select((s) => s.failure), (_, failure) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keepAll(templateFormFailureMessage(failure)))),
      );
      controller.failureShown();
    });
    ref.listen(provider.select((s) => s.outcome), (_, outcome) {
      if (outcome != null) Navigator.of(context).pop(outcome);
    });
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final members = ref.watch(membersProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final methods = ref.watch(paymentMethodsProvider).value ?? const [];
    final problems = state.problems;
    String? errorOf(Set<TemplateProblem> fieldProblems) {
      final problem = problems.where(fieldProblems.contains).firstOrNull;
      return problem == null ? null : keepAll(templateProblemMessage(problem));
    }

    final paidByCard = methods.any(
      (m) => m.id == state.paymentMethodId && m.kind == PaymentKind.card,
    );
    final enabled = !state.busy;
    final fields = <Widget>[
      WonAmountField(
        controller: _amount,
        fieldKey: const Key('template-amount'),
        optional: true,
        autofocus: !isEdit,
        enabled: enabled,
        errorText: null,
        onChanged: (_) {},
      ),
      LabeledField(
        label: '내용',
        child: TextField(
          key: const Key('template-title'),
          controller: _title,
          enabled: enabled,
          maxLength: entryTitleMaxLength,
          decoration: InputDecoration(
            counterText: '',
            hintText: '예: 관리비',
            errorText: errorOf({
              TemplateProblem.titleMissing,
              TemplateProblem.titleTooLong,
            }),
          ),
          textInputAction: TextInputAction.done,
          onChanged: (_) => controller.titleEdited(),
        ),
      ),
      ChoiceGroup(
        label: '누가',
        children: [
          for (final slot in MemberSlot.values)
            ChoicePill(
              key: Key('template-member-${slot.name}'),
              label: memberIn(members, slot).name,
              selected: state.memberId == slot.name,
              selectedColor: switch (slot) {
                MemberSlot.owner => context.appColors.sky,
                MemberSlot.partner => context.appColors.sea,
              },
              onSelected: enabled ? () => controller.selectMember(slot) : null,
            ),
        ],
      ),
      ChoiceGroup(
        label: '분류',
        errorText: errorOf({TemplateProblem.categoryMissing}),
        empty: categories.isEmpty ? '설정에서 분류를 먼저 추가해 주세요.' : null,
        children: [
          for (final category in categories)
            ChoicePill(
              key: Key('template-category-${category.id}'),
              label: category.name,
              selected: state.categoryId == category.id,
              onSelected: enabled
                  ? () => controller.selectCategory(category.id)
                  : null,
            ),
        ],
      ),
      ChoiceGroup(
        label: '결제수단',
        errorText: errorOf({TemplateProblem.paymentMethodMissing}),
        empty: methods.isEmpty ? '설정에서 결제수단을 먼저 추가해 주세요.' : null,
        note: paidByCard ? '카드로 낸 돈은 다음 달 카드대금으로 빠져나가요.' : null,
        noteKey: const Key('template-card-note'),
        children: [
          for (final method in methods)
            ChoicePill(
              key: Key('template-method-${method.id}'),
              label: method.name,
              selected: state.paymentMethodId == method.id,
              onSelected: enabled
                  ? () => controller.selectPaymentMethod(method.id)
                  : null,
            ),
        ],
      ),
      _DueDayField(
        dueDay: state.dueDay,
        errorText: errorOf({TemplateProblem.dueDayMissing}),
        onTap: enabled ? () => _pickDueDay(state.dueDay) : null,
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(
              keepAll(
                isEdit
                    ? '고치거나 지워도 이미 만든 달의 기본 지출은 그대로예요. 그달 것은 항목 탭에서 고쳐 주세요.'
                    : '저장하면 이번 달과 다음 달 기본 지출에도 들어가요.',
              ),
              key: const Key('template-form-note'),
              style: theme.textTheme.bodySmall,
            ),
            FilledButton(
              key: const Key('template-save'),
              onPressed: enabled ? _save : null,
              child: const Text('저장'),
            ),
            if (isEdit)
              TextButton.icon(
                key: const Key('template-delete'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.error,
                  minimumSize: const Size(64, 48),
                ),
                onPressed: enabled ? controller.delete : null,
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('삭제'),
              ),
          ],
        ),
      ),
    ];
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                FormNavBar(
                  title: isEdit ? '고정 지출 고치기' : '고정 지출 추가',
                  closeKey: const Key('template-close'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      for (final (index, field) in fields.indexed) ...[
                        if (index > 0) const SizedBox(height: 22),
                        field,
                      ],
                    ],
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

/// 매월 예정일 칸. 누르면 날짜를 고르는 시트가 뜬다.
///
/// 칸 전체가 하나의 버튼이라 이름표와 고른 값을 함께 읽게 직접 알린다.
class _DueDayField extends StatelessWidget {
  const _DueDayField({
    required this.dueDay,
    required this.errorText,
    required this.onTap,
  });

  final int? dueDay;
  final String? errorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueDay = this.dueDay;
    final text = dueDay == null ? null : '매월 ${dueDayLabel(dueDay)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        ExcludeSemantics(
          child: Text('예정일', style: theme.textTheme.labelMedium),
        ),
        Semantics(
          container: true,
          button: true,
          label: '예정일',
          value: text ?? '고르지 않음',
          child: InkWell(
            key: const Key('template-due-day'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: InputDecorator(
              isEmpty: text == null,
              decoration: InputDecoration(
                hintText: '매달 빠져나가는 날을 골라 주세요',
                errorText: errorText,
                enabled: onTap != null,
                suffixIcon: const ExcludeSemantics(
                  child: Icon(Icons.calendar_today_outlined, size: 20),
                ),
              ),
              child: ExcludeSemantics(
                child: Text(text ?? '', style: theme.textTheme.bodyLarge),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 매월 예정일을 고르는 시트. 1~30일과 말일을 한 주 7칸씩 놓는다. 고른 날을 돌려주며 닫힌다.
class _DueDaySheet extends StatelessWidget {
  const _DueDaySheet({required this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Semantics(
              header: true,
              child: Text('매월 예정일', style: theme.textTheme.titleMedium),
            ),
            Text(
              keepAll('그달에 없는 날(2월 30일 같은)은 그달 말일로 만들어져요.'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 48,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: lastDueDay,
              itemBuilder: (context, index) {
                final day = index + 1;
                return _DayButton(
                  key: Key('due-day-$day'),
                  label: day == lastDueDay ? dueDayLabel(day) : '$day',
                  selected: day == selected,
                  onTap: () => Navigator.of(context).pop(day),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 예정일 시트의 날짜 한 칸. 고른 날은 채워서 보여주고 화면 읽기 도구에 고른 상태를 알린다.
class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(12));
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? scheme.primary : scheme.outline),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
