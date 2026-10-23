import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/model/category.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/labeled_field.dart';
import 'category_form_controller.dart';
import 'setting_sheet.dart';

/// 분류 추가·고치기 시트. 이름과 저축 집계를 받고, 고칠 때는 숨기거나 다시 보이게 한다.
/// 저장하거나 숨기면 [SettingFormOutcome]을 돌려주며 닫힌다.
class CategorySheet extends ConsumerStatefulWidget {
  const CategorySheet({required this.args, super.key});

  final CategoryFormArgs args;

  @override
  ConsumerState<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<CategorySheet> {
  // 입력란 글자는 화면에만 필요한 상태라 위젯이 갖고, 저장할 때 컨트롤러에 넘긴다.
  late final TextEditingController _name = TextEditingController(
    text: widget.args.category?.name ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => ref
      .read(categoryFormControllerProvider(widget.args).notifier)
      .save(_name.text);

  @override
  Widget build(BuildContext context) {
    final category = widget.args.category;
    final provider = categoryFormControllerProvider(widget.args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider.select((s) => s.outcome), (_, outcome) {
      if (outcome != null) Navigator.of(context).pop(outcome);
    });
    final theme = Theme.of(context);
    final problem = state.problem;
    final failure = state.failure;
    final enabled = !state.busy;
    // 숨겨도 고정 지출은 이 분류로 계속 기본 지출을 만든다. 쓰는 고정 지출이 있으면 미리 알린다.
    final usedByTemplates = category == null
        ? 0
        : (ref.watch(templatesProvider).value ?? const [])
              .where((t) => t.categoryId == category.id)
              .length;
    return SettingSheet(
      title: category == null ? '분류 추가' : '분류 고치기',
      children: [
        LabeledField(
          label: '이름',
          child: TextField(
            key: const Key('category-name'),
            controller: _name,
            autofocus: category == null,
            enabled: enabled,
            maxLength: categoryNameMaxLength,
            decoration: InputDecoration(
              counterText: '',
              hintText: '예: 경조사',
              errorText: problem == null
                  ? null
                  : keepAll(
                      nameProblemMessage(
                        problem,
                        maxLength: categoryNameMaxLength,
                      ),
                    ),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) => controller.nameEdited(),
            onSubmitted: (_) => _save(),
          ),
        ),
        SwitchListTile(
          key: const Key('category-saving'),
          contentPadding: EdgeInsets.zero,
          title: const Text('저축으로 집계'),
          subtitle: Text(keepAll('이 분류의 기본 지출을 월 요약의 저축에 더해요.')),
          value: state.countsAsSaving,
          onChanged: enabled ? controller.setCountsAsSaving : null,
        ),
        if (category != null && !category.hidden && usedByTemplates > 0)
          Text(
            keepAll(
              '고정 지출 $usedByTemplates개가 이 분류를 써요. 숨겨도 그 고정 지출은 이 분류로 계속 만들어져요.',
            ),
            key: const Key('category-used-note'),
            style: theme.textTheme.bodySmall,
          ),
        if (failure != null) SheetFailureText(failure),
        FilledButton(
          key: const Key('category-save'),
          onPressed: enabled ? _save : null,
          child: const Text('저장'),
        ),
        if (category != null)
          HideButton(
            hidden: category.hidden,
            onPressed: enabled
                ? () => controller.setHidden(!category.hidden)
                : null,
          ),
      ],
    );
  }
}
