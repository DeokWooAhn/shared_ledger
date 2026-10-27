import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/model/payment_method.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/tab_page.dart';
import 'payment_method_form_notifier.dart';
import 'payment_method_sheet.dart';
import 'setting_form.dart';
import 'setting_list.dart';
import 'setting_sheet.dart';

/// 결제수단·카드 목록 화면. 설정 탭에서 들어온다(탭 막대는 그대로 보인다).
///
/// 보이는 결제수단을 순서대로 두고, 숨긴 것은 아래에 따로 모은다. 줄을 누르면 시트에서 이름을 고치거나 숨기고,
/// 아래 단추로 새 결제수단(카드는 카드마다 하나)을 맨 뒤에 더한다. 보기 전용은 보기만 한다.
class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    return TabPage(
      header: const SubPageTitle(
        '결제수단·카드',
        description: '카드는 카드마다 하나씩 추가해요. 카드로 낸 돈은 다음 달 카드대금으로 빠져나가요.',
      ),
      children: [
        switch (methods) {
          AsyncData(:final value) => _PaymentMethodsContent(methods: value),
          AsyncError() => const SettingListMessage(
            '결제수단을 불러오지 못했어요. 잠시 후 다시 열어 주세요.',
          ),
          _ => const SettingListLoading(),
        },
      ],
    );
  }
}

class _PaymentMethodsContent extends ConsumerWidget {
  const _PaymentMethodsContent({required this.methods});

  final List<PaymentMethod> methods;

  // 시트를 열고, 숨기거나 다시 보이게 하고 닫히면 스낵바로 알린다.
  Future<void> _open(BuildContext context, PaymentMethodFormArgs args) async {
    // await 뒤에는 context가 사라졌을 수 있어서 미리 잡아 둔다.
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await showSettingSheet<SettingFormOutcome>(
      context,
      (_) => PaymentMethodSheet(args: args),
    );
    final message = settingOutcomeMessage(outcome);
    if (message == null) return;
    messenger.showSnackBar(
      SnackBar(
        key: const Key('setting-outcome'),
        content: Text(keepAll(message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canWrite = ref.watch(myRoleProvider)?.canWrite ?? false;
    final visible = [...methods.where((m) => !m.hidden)];
    final hidden = [...methods.where((m) => m.hidden)];
    VoidCallback? edit(PaymentMethod method) => canWrite
        ? () => _open(context, PaymentMethodFormArgs.edit(method))
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        if (!canWrite) const ViewOnlyNotice(),
        if (visible.isEmpty)
          const SettingListMessage('쓸 수 있는 결제수단이 없어요. 통장이나 카드를 추가해 주세요.')
        else
          SettingCard(
            children: [
              for (final m in visible) _MethodRow(method: m, onTap: edit(m)),
            ],
          ),
        if (canWrite)
          FilledButton.tonal(
            key: const Key('add-payment-method'),
            onPressed: () => _open(context, const PaymentMethodFormArgs.add()),
            child: const Text('결제수단·카드 추가'),
          ),
        if (hidden.isNotEmpty)
          SettingCard(
            key: const Key('hidden-payment-methods'),
            title: '숨긴 결제수단',
            children: [
              for (final m in hidden) _MethodRow(method: m, onTap: edit(m)),
            ],
          ),
      ],
    );
  }
}

/// 결제수단 한 줄. 종류 아이콘과 종류 이름을 같이 보여준다.
class _MethodRow extends StatelessWidget {
  _MethodRow({required this.method, required this.onTap})
    : super(key: ValueKey('method-${method.id}'));

  final PaymentMethod method;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SettingRow(
    leading: SettingIconTile(paymentKindIcon(method.kind)),
    title: method.name,
    value: paymentKindLabel(method.kind),
    onTap: onTap,
  );
}
