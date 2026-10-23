import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widget/keep_all.dart';
import '../../core/widget/labeled_field.dart';
import 'rename_controller.dart';
import 'setting_sheet.dart';

/// 이름 바꾸기 시트. 가계부 이름이나 이름표 이름을 고친다. 설정 탭에서 열고, 저장하면 닫힌다.
class RenameSheet extends ConsumerStatefulWidget {
  const RenameSheet({
    required this.target,
    required this.initialName,
    super.key,
  });

  final RenameTarget target;

  /// 처음 입력란에 넣을 지금 이름.
  final String initialName;

  @override
  ConsumerState<RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends ConsumerState<RenameSheet> {
  // 입력란 글자는 화면에만 필요한 상태라 위젯이 갖고, 저장할 때 컨트롤러에 넘긴다.
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => ref
      .read(renameControllerProvider(widget.target).notifier)
      .save(_name.text);

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final provider = renameControllerProvider(target);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider.select((s) => s.done), (_, done) {
      if (done) Navigator.of(context).pop();
    });
    final problem = state.problem;
    final failure = state.failure;
    final (title, description, hint) = switch (target) {
      LedgerNameTarget() => ('가계부 이름', '두 사람 모두에게 같은 이름으로 보여요.', '예: 우리 가계부'),
      MemberNameTarget() => (
        '이름표 이름',
        '항목의 \'누가\'와 월 요약에 이 이름으로 보여요.',
        '예: 하늘',
      ),
    };
    return SettingSheet(
      title: title,
      children: [
        Text(
          keepAll(description),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        LabeledField(
          label: '이름',
          child: TextField(
            key: const Key('rename-field'),
            controller: _name,
            autofocus: true,
            enabled: !state.busy,
            maxLength: target.maxLength,
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              errorText: problem == null
                  ? null
                  : keepAll(
                      nameProblemMessage(problem, maxLength: target.maxLength),
                    ),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) => controller.nameEdited(),
            onSubmitted: (_) => _save(),
          ),
        ),
        if (failure != null) SheetFailureText(failure),
        FilledButton(
          key: const Key('rename-save'),
          onPressed: state.busy ? null : _save,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
