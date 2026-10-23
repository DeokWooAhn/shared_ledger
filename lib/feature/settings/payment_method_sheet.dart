import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/model/payment_method.dart';
import '../../core/widget/form_parts.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/labeled_field.dart';
import 'payment_method_form_controller.dart';
import 'setting_sheet.dart';

/// 화면에 보이는 결제수단 종류 이름.
String paymentKindLabel(PaymentKind kind) => switch (kind) {
  PaymentKind.account => '계좌·현금',
  PaymentKind.autoTransfer => '자동이체',
  PaymentKind.card => '카드',
};

/// 결제수단 종류 아이콘.
IconData paymentKindIcon(PaymentKind kind) => switch (kind) {
  PaymentKind.account => Icons.account_balance_outlined,
  PaymentKind.autoTransfer => Icons.autorenew,
  PaymentKind.card => Icons.credit_card,
};

/// 결제수단(카드 포함) 추가·고치기 시트. 새로 더할 때는 이름과 종류를, 고칠 때는 이름만 받고 숨기거나 다시 보이게 한다.
/// 저장하거나 숨기면 [SettingFormOutcome]을 돌려주며 닫힌다.
class PaymentMethodSheet extends ConsumerStatefulWidget {
  const PaymentMethodSheet({required this.args, super.key});

  final PaymentMethodFormArgs args;

  @override
  ConsumerState<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends ConsumerState<PaymentMethodSheet> {
  // 입력란 글자는 화면에만 필요한 상태라 위젯이 갖고, 저장할 때 컨트롤러에 넘긴다.
  late final TextEditingController _name = TextEditingController(
    text: widget.args.method?.name ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => ref
      .read(paymentMethodFormControllerProvider(widget.args).notifier)
      .save(_name.text);

  @override
  Widget build(BuildContext context) {
    final method = widget.args.method;
    final provider = paymentMethodFormControllerProvider(widget.args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider.select((s) => s.outcome), (_, outcome) {
      if (outcome != null) Navigator.of(context).pop(outcome);
    });
    final theme = Theme.of(context);
    final problem = state.problem;
    final failure = state.failure;
    final enabled = !state.busy;
    // 숨겨도 고정 지출은 이 결제수단으로 계속 기본 지출을 만든다. 쓰는 고정 지출이 있으면 미리 알린다.
    final usedByTemplates = method == null
        ? 0
        : (ref.watch(templatesProvider).value ?? const [])
              .where((t) => t.paymentMethodId == method.id)
              .length;
    return SettingSheet(
      title: method == null ? '결제수단 추가' : '결제수단 고치기',
      children: [
        LabeledField(
          label: '이름',
          child: TextField(
            key: const Key('method-name'),
            controller: _name,
            autofocus: method == null,
            enabled: enabled,
            maxLength: paymentMethodNameMaxLength,
            decoration: InputDecoration(
              counterText: '',
              hintText: '예: 하늘 카드',
              errorText: problem == null
                  ? null
                  : keepAll(
                      nameProblemMessage(
                        problem,
                        maxLength: paymentMethodNameMaxLength,
                      ),
                    ),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) => controller.nameEdited(),
            onSubmitted: (_) => _save(),
          ),
        ),
        if (method == null)
          ChoiceGroup(
            label: '종류',
            errorText: state.kindMissing ? keepAll('종류를 골라 주세요.') : null,
            note: state.kind == PaymentKind.card
                ? '카드로 낸 돈은 다음 달 카드대금으로 빠져나가요. 카드대금은 항목 탭에서 이 카드로 적어요.'
                : null,
            noteKey: const Key('method-card-note'),
            children: [
              for (final kind in PaymentKind.values)
                ChoicePill(
                  key: Key('method-kind-${kind.name}'),
                  label: paymentKindLabel(kind),
                  selected: state.kind == kind,
                  onSelected: enabled
                      ? () => controller.selectKind(kind)
                      : null,
                ),
            ],
          )
        else
          _KindReadOnly(kind: method.kind),
        if (method == null)
          Text(
            keepAll('종류는 만든 뒤에 바꿀 수 없어요. 카드인지에 따라 지난 달 계산이 달라져서예요.'),
            style: theme.textTheme.labelSmall,
          ),
        if (method != null && !method.hidden && usedByTemplates > 0)
          Text(
            keepAll(
              '고정 지출 $usedByTemplates개가 이 결제수단을 써요. 숨겨도 그 고정 지출은 이 결제수단으로 계속 만들어져요.',
            ),
            key: const Key('method-used-note'),
            style: theme.textTheme.bodySmall,
          ),
        if (failure != null) SheetFailureText(failure),
        FilledButton(
          key: const Key('method-save'),
          onPressed: enabled ? _save : null,
          child: const Text('저장'),
        ),
        if (method != null)
          HideButton(
            hidden: method.hidden,
            onPressed: enabled
                ? () => controller.setHidden(!method.hidden)
                : null,
          ),
      ],
    );
  }
}

/// 고칠 때 보여 주는 종류. 바꿀 수 없다고 함께 알린다.
class _KindReadOnly extends StatelessWidget {
  const _KindReadOnly({required this.kind});

  final PaymentKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Row(
        spacing: 10,
        children: [
          Icon(paymentKindIcon(kind), size: 20),
          Text(paymentKindLabel(kind), style: theme.textTheme.bodyLarge),
          Expanded(
            child: Text(
              keepAll('종류는 바꿀 수 없어요.'),
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
