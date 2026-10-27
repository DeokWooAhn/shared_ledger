import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/ledger.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/labeled_field.dart';
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
      LedgerStartFailure.join => '참여하지 못했어요. 잠시 후 다시 시도해 주세요.',
    };

/// 가계부 시작 화면(design/app.pen의 02). 새로 만들거나 초대 코드로 참여한다.
/// 만든 사람이 관리자가 되고, 초대 코드로 들어온 사람은 초대에 정해진 역할을 받는다.
class LedgerStartScreen extends ConsumerStatefulWidget {
  const LedgerStartScreen({super.key});

  @override
  ConsumerState<LedgerStartScreen> createState() => _LedgerStartScreenState();
}

class _LedgerStartScreenState extends ConsumerState<LedgerStartScreen> {
  // 입력란 내용과 폼은 화면에만 필요한 상태라 위젯이 갖는다.
  final _createForm = GlobalKey<FormState>();
  final _name = TextEditingController(text: '우리 가계부');
  final _code = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _create() {
    // 가계부 이름은 이 입력란 안에서 끝나는 검사라 폼 검사기로 한다.
    if (!(_createForm.currentState?.validate() ?? false)) return;
    ref.read(ledgerStartNotifierProvider.notifier).create(_name.text);
  }

  void _join() =>
      ref.read(ledgerStartNotifierProvider.notifier).join(_code.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(ledgerStartNotifierProvider);
    final notifier = ref.read(ledgerStartNotifierProvider.notifier);
    ref.listen(ledgerStartNotifierProvider.select((s) => s.failure), (
      _,
      failure,
    ) {
      if (failure == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keepAll(ledgerStartFailureMessage(failure)))),
      );
      notifier.failureShown();
    });
    final codeProblem = state.codeProblem;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        keepAll('함께 쓸 가계부를 정해요'),
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        keepAll('한 사람이 가계부를 만들고, 다른 한 사람은 초대 코드로 들어와요.'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _OptionCard(
                  icon: Icons.add,
                  title: '새로 만들기',
                  description: '내가 관리자가 돼요',
                  children: [
                    Form(
                      key: _createForm,
                      child: LabeledField(
                        label: '가계부 이름',
                        child: TextFormField(
                          key: const Key('ledger-name'),
                          controller: _name,
                          enabled: !state.busy,
                          maxLength: ledgerNameMaxLength,
                          decoration: const InputDecoration(counterText: ''),
                          validator: (value) =>
                              keepAllOrNull(validateLedgerName(value)),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _create(),
                        ),
                      ),
                    ),
                    FilledButton(
                      key: const Key('create-ledger'),
                      onPressed: state.busy ? null : _create,
                      child: const Text('만들기'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _OptionCard(
                  icon: Icons.confirmation_number_outlined,
                  title: '초대 코드로 참여',
                  description: '받은 코드를 넣으면 바로 같이 써요',
                  children: [
                    LabeledField(
                      label: '초대 코드',
                      child: TextField(
                        key: const Key('invite-code'),
                        controller: _code,
                        enabled: !state.busy,
                        decoration: InputDecoration(
                          hintText: '받은 코드를 붙여 넣어 주세요',
                          errorText: codeProblem == null
                              ? null
                              : keepAll(inviteCodeProblemMessage(codeProblem)),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => notifier.codeEdited(),
                        onSubmitted: (_) => _join(),
                      ),
                    ),
                    Text(
                      keepAll('초대 코드는 만든 날부터 7일 동안 쓸 수 있어요.'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                    OutlinedButton(
                      key: const Key('join-ledger'),
                      onPressed: state.busy ? null : _join,
                      child: const Text('참여하기'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    key: const Key('sign-out'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: state.busy
                        ? null
                        : () => signOutWithFeedback(context, ref),
                    child: const Text('로그아웃'),
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

/// 아이콘·제목·설명 아래에 입력란과 버튼을 두는 선택지 카드.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(keepAll(title), style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        keepAll(description),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            for (final child in children) ...[
              const SizedBox(height: 16),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
