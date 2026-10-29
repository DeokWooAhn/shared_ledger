import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widget/form_parts.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/labeled_field.dart';
import 'ledger_start_notifier.dart';
import 'ledger_start_screen.dart';

/// 초대 코드로 입장 화면(design/app/02b). 상대가 만든 가계부의 초대 코드를 넣어 들어간다.
///
/// 들어오면 초대에 정해진 역할을 받고, 가계부 목록이 바뀌어 화면 이동 규칙(router.dart)이 홈으로 옮긴다.
class JoinLedgerScreen extends ConsumerStatefulWidget {
  const JoinLedgerScreen({super.key});

  @override
  ConsumerState<JoinLedgerScreen> createState() => _JoinLedgerScreenState();
}

class _JoinLedgerScreenState extends ConsumerState<JoinLedgerScreen> {
  // 입력란 내용은 화면에만 필요한 상태라 위젯이 갖는다.
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _join() =>
      ref.read(ledgerStartNotifierProvider.notifier).join(_code.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(ledgerStartNotifierProvider);
    final notifier = ref.read(ledgerStartNotifierProvider.notifier);
    listenLedgerStartFailure(context, ref);
    final codeProblem = state.codeProblem;
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const FormNavBar(
                  title: '초대 코드로 입장',
                  closeKey: Key('join-back'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Text(
                        keepAll('상대에게 받은 초대 코드를 넣어 주세요.'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
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
                                : keepAll(
                                    inviteCodeProblemMessage(codeProblem),
                                  ),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => notifier.codeEdited(),
                          onSubmitted: (_) => _join(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        keepAll('초대 코드는 만든 날부터 7일 동안 쓸 수 있어요.'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        key: const Key('join-ledger'),
                        onPressed: state.busy ? null : _join,
                        child: const Text('입장하기'),
                      ),
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
