import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/model/category.dart';
import '../../core/widget/keep_all.dart';
import '../../core/widget/tab_page.dart';
import 'category_form_notifier.dart';
import 'category_sheet.dart';
import 'setting_form.dart';
import 'setting_list.dart';
import 'setting_sheet.dart';

/// 분류 목록 화면. 설정 탭에서 들어온다(탭 막대는 그대로 보인다).
///
/// 보이는 분류를 순서대로 두고, 숨긴 분류는 아래에 따로 모은다. 줄을 누르면 시트에서 고치거나 숨기고,
/// 아래 단추로 새 분류를 맨 뒤에 더한다. 보기 전용은 보기만 한다.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return TabPage(
      header: const SubPageTitle(
        '분류',
        description: '고정 지출을 이 분류로 묶어요. 저축으로 집계하는 분류는 월 요약의 저축에 더해요.',
      ),
      children: [
        switch (categories) {
          AsyncData(:final value) => _CategoriesContent(categories: value),
          AsyncError() => const SettingListMessage(
            '분류를 불러오지 못했어요. 잠시 후 다시 열어 주세요.',
          ),
          _ => const SettingListLoading(),
        },
      ],
    );
  }
}

class _CategoriesContent extends ConsumerWidget {
  const _CategoriesContent({required this.categories});

  final List<Category> categories;

  // 시트를 열고, 숨기거나 다시 보이게 하고 닫히면 스낵바로 알린다.
  Future<void> _open(BuildContext context, CategoryFormArgs args) async {
    // await 뒤에는 context가 사라졌을 수 있어서 미리 잡아 둔다.
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await showSettingSheet<SettingFormOutcome>(
      context,
      (_) => CategorySheet(args: args),
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
    final visible = [...categories.where((c) => !c.hidden)];
    final hidden = [...categories.where((c) => c.hidden)];
    VoidCallback? edit(Category category) =>
        canWrite ? () => _open(context, CategoryFormArgs.edit(category)) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        if (!canWrite) const ViewOnlyNotice(),
        if (visible.isEmpty)
          const SettingListMessage('쓸 수 있는 분류가 없어요. 분류를 추가해 주세요.')
        else
          SettingCard(
            children: [
              for (final c in visible)
                _CategoryRow(category: c, onTap: edit(c)),
            ],
          ),
        if (canWrite)
          FilledButton.tonal(
            key: const Key('add-category'),
            onPressed: () => _open(context, const CategoryFormArgs.add()),
            child: const Text('분류 추가'),
          ),
        if (hidden.isNotEmpty)
          SettingCard(
            key: const Key('hidden-categories'),
            title: '숨긴 분류',
            children: [
              for (final c in hidden) _CategoryRow(category: c, onTap: edit(c)),
            ],
          ),
      ],
    );
  }
}

/// 분류 한 줄. 저축으로 집계하는 분류에는 '저축' 표시를 붙인다.
class _CategoryRow extends StatelessWidget {
  _CategoryRow({required this.category, required this.onTap})
    : super(key: ValueKey('category-${category.id}'));

  final Category category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SettingRow(
    title: category.name,
    badge: category.countsAsSaving ? const SettingChip('저축') : null,
    onTap: onTap,
  );
}
