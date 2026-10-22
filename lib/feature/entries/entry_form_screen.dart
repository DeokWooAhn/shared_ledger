import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/model/ledger_entries.dart';
import '../../core/model/member.dart';
import '../../core/model/payment_method.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/form_parts.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/labeled_field.dart';
import '../../core/widget/won_input.dart';
import 'entry_form_controller.dart';
import 'entry_kind_tabs.dart';

/// 입력란 아래에 보여 줄 문구.
String entryProblemMessage(EntryProblem problem) => switch (problem) {
  EntryProblem.amountMissing => '금액을 입력해 주세요.',
  EntryProblem.titleMissing => '내용을 입력해 주세요.',
  EntryProblem.titleTooLong => '내용은 $entryTitleMaxLength자까지 쓸 수 있어요.',
  EntryProblem.categoryMissing => '분류를 골라 주세요.',
  EntryProblem.paymentMethodMissing => '결제수단을 골라 주세요.',
  EntryProblem.cardMissing => '카드를 골라 주세요.',
  EntryProblem.memoTooLong => '메모는 $entryMemoMaxLength자까지 쓸 수 있어요.',
};

String entryFormFailureMessage(EntryFormFailure failure) => switch (failure) {
  EntryFormFailure.offline => '인터넷에 연결된 뒤에 다시 시도해 주세요. 고치기와 휴지통은 연결돼 있을 때만 돼요.',
  EntryFormFailure.gone => '그사이 휴지통에 들어갔거나 지워진 항목이에요.',
  EntryFormFailure.save => '저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
  EntryFormFailure.trash => '휴지통에 넣지 못했어요. 잠시 후 다시 시도해 주세요.',
};

/// 날짜 칸의 이름표.
String entryDateLabel(EntryKind kind) => switch (kind) {
  EntryKind.income => '받은 날',
  EntryKind.planned => '지급한 날',
  EntryKind.extra => '쓴 날',
  EntryKind.cardBill => '출금일',
};

/// 입력 화면에 보이는 날짜. 예: '2026년 10월 18일'
String entryLongDate(DateTime date) =>
    '${date.year}년 ${date.month}월 ${date.day}일';

String _titleHint(EntryKind kind) => switch (kind) {
  EntryKind.income => '예: 월급',
  EntryKind.planned => '예: 관리비',
  EntryKind.extra || EntryKind.cardBill => '예: 마트 장보기',
};

/// 항목 입력·수정 화면(design/app/05). X로 닫는 전체 화면이고, 넓은 화면에서는 가운데 560폭으로 둔다.
///
/// 종류마다 칸이 다르다. 기본 월 지출은 분류와 지급 완료, 수입은 받은 날, 카드대금은 어느 카드인지를 받는다.
/// 저장하거나 휴지통에 넣으면 [EntryFormOutcome]을 돌려주며 닫힌다.
class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({required this.args, super.key});

  final EntryFormArgs args;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  // 입력란 글자는 화면에만 필요한 상태라 위젯이 갖고, 저장할 때 컨트롤러에 넘긴다.
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late final TextEditingController _memo;

  @override
  void initState() {
    super.initState();
    final entry = widget.args.entry;
    _amount = TextEditingController(text: wonInputText(entry?.amount));
    _title = TextEditingController(
      text: switch (entry) {
        Income(:final title) ||
        PlannedExpense(:final title) ||
        ExtraExpense(:final title) => title,
        CardBill() || null => '',
      },
    );
    _memo = TextEditingController(text: entry?.memo ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _save() => ref
      .read(entryFormControllerProvider(widget.args).notifier)
      .save(amount: _amount.text, title: _title.text, memo: _memo.text);

  Future<void> _pickDate(EntryFormState state) async {
    final month = widget.args.month;
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    // 달력은 처음 날짜가 고를 수 있는 범위 밖이면 멈춘다. 잘못 저장된 날짜도 그달 안으로 맞춘다.
    final wanted = state.date ?? today;
    final initial = wanted.isBefore(first)
        ? first
        : wanted.isAfter(last)
        ? last
        : wanted;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      currentDate: today,
      helpText: entryDateLabel(state.kind),
    );
    if (picked == null || !mounted) return;
    ref
        .read(entryFormControllerProvider(widget.args).notifier)
        .selectDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final isEdit = args.entry != null;
    final provider = entryFormControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider.select((s) => s.failure), (_, failure) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keepAll(entryFormFailureMessage(failure)))),
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
    final cards = [
      for (final method in methods)
        if (method.kind == PaymentKind.card) method,
    ];
    final kind = state.kind;
    final problems = state.problems;
    String? errorOf(Set<EntryProblem> fieldProblems) {
      final problem = problems.where(fieldProblems.contains).firstOrNull;
      return problem == null ? null : keepAll(entryProblemMessage(problem));
    }

    final paidByCard = methods.any(
      (m) => m.id == state.paymentMethodId && m.kind == PaymentKind.card,
    );
    final enabled = !state.busy;
    final fields = <Widget>[
      EntryKindTabs(
        selected: kind,
        onSelect: isEdit || !enabled ? null : controller.selectKind,
      ),
      WonAmountField(
        controller: _amount,
        fieldKey: const Key('entry-amount'),
        optional: kind == EntryKind.planned,
        autofocus: !isEdit,
        enabled: enabled,
        errorText: errorOf({EntryProblem.amountMissing}),
        onChanged: (_) => controller.textEdited(EntryTextField.amount),
      ),
      if (kind != EntryKind.cardBill)
        LabeledField(
          label: '내용',
          child: TextField(
            key: const Key('entry-title'),
            controller: _title,
            enabled: enabled,
            maxLength: entryTitleMaxLength,
            decoration: InputDecoration(
              counterText: '',
              hintText: _titleHint(kind),
              errorText: errorOf({
                EntryProblem.titleMissing,
                EntryProblem.titleTooLong,
              }),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => controller.textEdited(EntryTextField.title),
          ),
        ),
      ChoiceGroup(
        label: '누가',
        children: [
          for (final slot in MemberSlot.values)
            ChoicePill(
              key: Key('entry-member-${slot.name}'),
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
      if (kind == EntryKind.planned)
        ChoiceGroup(
          label: '분류',
          errorText: errorOf({EntryProblem.categoryMissing}),
          empty: categories.isEmpty ? '설정에서 분류를 먼저 추가해 주세요.' : null,
          children: [
            for (final category in categories)
              ChoicePill(
                key: Key('entry-category-${category.id}'),
                label: category.name,
                selected: state.categoryId == category.id,
                onSelected: enabled
                    ? () => controller.selectCategory(category.id)
                    : null,
              ),
          ],
        ),
      if (kind == EntryKind.planned || kind == EntryKind.extra)
        ChoiceGroup(
          label: '결제수단',
          errorText: errorOf({EntryProblem.paymentMethodMissing}),
          empty: methods.isEmpty ? '설정에서 결제수단을 먼저 추가해 주세요.' : null,
          note: paidByCard ? '카드로 낸 돈은 다음 달 카드대금으로 빠져나가요.' : null,
          noteKey: const Key('entry-card-note'),
          children: [
            for (final method in methods)
              ChoicePill(
                key: Key('entry-method-${method.id}'),
                label: method.name,
                selected: state.paymentMethodId == method.id,
                onSelected: enabled
                    ? () => controller.selectPaymentMethod(method.id)
                    : null,
              ),
          ],
        ),
      if (kind == EntryKind.cardBill)
        ChoiceGroup(
          label: '카드',
          errorText: errorOf({EntryProblem.cardMissing}),
          empty: cards.isEmpty ? '카드가 아직 없어요. 설정에서 카드를 추가한 뒤 적어 주세요.' : null,
          children: [
            for (final card in cards)
              ChoicePill(
                key: Key('entry-card-${card.id}'),
                label: card.name,
                selected: state.cardId == card.id,
                onSelected: enabled
                    ? () => controller.selectCard(card.id)
                    : null,
              ),
          ],
        ),
      if (kind == EntryKind.planned)
        _PaidSwitch(
          paid: state.paid,
          onChanged: enabled ? controller.setPaid : null,
        ),
      if (kind != EntryKind.planned || state.paid)
        _DateField(
          label: entryDateLabel(kind),
          date: state.date,
          // 기본 월 지출의 지급한 날은 지급 완료 스위치로 비운다.
          onClear: kind == EntryKind.planned || !enabled
              ? null
              : controller.clearDate,
          onTap: enabled ? () => _pickDate(state) : null,
        ),
      LabeledField(
        label: '메모',
        child: TextField(
          key: const Key('entry-memo'),
          controller: _memo,
          enabled: enabled,
          maxLength: entryMemoMaxLength,
          decoration: InputDecoration(
            counterText: '',
            hintText: '메모를 남길 수 있어요 (선택)',
            errorText: errorOf({EntryProblem.memoTooLong}),
          ),
          textInputAction: TextInputAction.done,
          onChanged: (_) => controller.textEdited(EntryTextField.memo),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            FilledButton(
              key: const Key('entry-save'),
              onPressed: enabled ? _save : null,
              child: const Text('저장'),
            ),
            if (isEdit)
              TextButton.icon(
                key: const Key('entry-trash'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.error,
                  minimumSize: const Size(64, 48),
                ),
                onPressed: enabled ? controller.trash : null,
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('휴지통에 넣기'),
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
                  title: isEdit ? '항목 고치기' : '항목 추가',
                  closeKey: const Key('entry-close'),
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

/// 기본 월 지출의 지급 완료 스위치. 켜면 지급한 날 칸이 나온다.
class _PaidSwitch extends StatelessWidget {
  const _PaidSwitch({required this.paid, required this.onChanged});

  final bool paid;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      key: const Key('entry-paid'),
      contentPadding: EdgeInsets.zero,
      value: paid,
      onChanged: onChanged,
      title: Text(
        '지급 완료',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        keepAll(paid ? '현금 유출에 들어가요.' : '아직 빠져나가지 않은 돈이에요.'),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

/// 날짜 칸. 누르면 달력이 뜬다. [onClear]가 있으면 날짜를 비우는 단추를 둔다.
///
/// 안에 '날짜 지우기' 단추가 따로 있어서 [LabeledField](이름표와 칸을 하나로 합침)를 쓰지 않고,
/// 칸을 이름표·날짜를 읽어 주는 버튼으로 직접 알린다.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = this.date;
    final onClear = this.onClear;
    final text = date == null ? null : entryLongDate(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        ExcludeSemantics(
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        Semantics(
          container: true,
          button: true,
          label: label,
          value: text ?? '고르지 않음',
          child: InkWell(
            key: const Key('entry-date'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: InputDecorator(
              isEmpty: text == null,
              decoration: InputDecoration(
                hintText: '날짜를 고를 수 있어요 (선택)',
                enabled: onTap != null,
                suffixIcon: text == null || onClear == null
                    ? const ExcludeSemantics(
                        child: Icon(Icons.calendar_today_outlined, size: 20),
                      )
                    : IconButton(
                        key: const Key('entry-date-clear'),
                        tooltip: '날짜 지우기',
                        onPressed: onClear,
                        icon: const Icon(Icons.close, size: 20),
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
