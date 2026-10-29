import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/clock.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/form_parts.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/labeled_field.dart';
import '../../core/widget/month_picker_sheet.dart';
import '../../domain/model/ledger.dart';
import '../../domain/model/year_month.dart';
import 'ledger_start_notifier.dart';
import 'ledger_start_screen.dart';

/// 가계부 만들기 화면(design/app/02a). 가계부 이름과 처음 쓸 달을 정해 만든다.
///
/// 만든 사람이 관리자가 된다. 처음 쓸 달은 이번 달로 시작하고, 연·월 휠로 바꾼다. 다른 달은 나중에 가계부 탭에서 더한다.
/// 만들면 가계부 목록이 바뀌고 화면 이동 규칙(router.dart)이 홈으로 옮긴다.
class CreateLedgerScreen extends ConsumerStatefulWidget {
  const CreateLedgerScreen({super.key});

  @override
  ConsumerState<CreateLedgerScreen> createState() => _CreateLedgerScreenState();
}

class _CreateLedgerScreenState extends ConsumerState<CreateLedgerScreen> {
  // 입력란 내용과 폼, 고른 첫 달은 화면에만 필요한 상태라 위젯이 갖는다.
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: '우리 가계부');
  late YearMonth _firstMonth = YearMonth.of(ref.read(clockProvider)());

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    // 가계부 이름은 이 입력란 안에서 끝나는 검사라 폼 검사기로 한다.
    if (!(_form.currentState?.validate() ?? false)) return;
    ref
        .read(ledgerStartNotifierProvider.notifier)
        .create(_name.text, firstMonth: _firstMonth);
  }

  Future<void> _pickFirstMonth() async {
    final picked = await showMonthPicker(
      context,
      selected: _firstMonth,
      current: YearMonth.of(ref.read(clockProvider)()),
    );
    if (picked == null || !mounted) return;
    setState(() => _firstMonth = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(ledgerStartNotifierProvider);
    listenLedgerStartFailure(context, ref);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const FormNavBar(
                  title: '가계부 만들기',
                  closeKey: Key('create-back'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Text(
                        keepAll('두 사람이 함께 쓸 가계부를 만들어요. 만든 사람이 관리자가 돼요.'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Form(
                        key: _form,
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
                      const SizedBox(height: 22),
                      _FirstMonthField(
                        month: _firstMonth,
                        onTap: state.busy ? null : _pickFirstMonth,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        keepAll('다른 달은 나중에 가계부 탭에서 더할 수 있어요.'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        key: const Key('create-ledger'),
                        onPressed: state.busy ? null : _create,
                        child: const Text('만들기'),
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

/// 처음 쓸 달 칸. 누르면 연·월 휠 시트가 뜬다. 칸 전체가 하나의 버튼이라 이름표와 고른 달을 함께 읽게 직접 알린다.
class _FirstMonthField extends StatelessWidget {
  const _FirstMonthField({required this.month, required this.onTap});

  final YearMonth month;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = '${month.year}년 ${month.month}월';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        ExcludeSemantics(
          child: Text('첫 달', style: theme.textTheme.labelMedium),
        ),
        Semantics(
          container: true,
          button: true,
          label: '첫 달',
          value: text,
          child: InkWell(
            key: const Key('first-month'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: InputDecorator(
              decoration: InputDecoration(
                enabled: onTap != null,
                suffixIcon: const ExcludeSemantics(
                  child: Icon(Icons.keyboard_arrow_down, size: 22),
                ),
              ),
              child: ExcludeSemantics(
                child: Text(text, style: theme.textTheme.bodyLarge),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
