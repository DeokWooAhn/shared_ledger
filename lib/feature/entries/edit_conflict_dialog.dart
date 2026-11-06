import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/widget/keep_all.dart';
import '../../domain/format/won.dart';
import '../../domain/model/entry_edit.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/member.dart';
import 'entry_form_screen.dart';

/// 고치기가 상대와 겹쳤을 때 묻는 창을 띄우고 고른 것을 돌려준다. 취소하면 null.
Future<EditConflictChoice?> showEditConflictDialog(
  BuildContext context,
  EntryEditConflict conflict,
) => showDialog<EditConflictChoice>(
  context: context,
  builder: (_) => EditConflictDialog(conflict: conflict),
);

/// 겹친 칸의 이름. 입력 화면의 칸 이름과 같다.
String editFieldLabel(EntryField field, EntryKind kind) => switch (field) {
  EntryField.member => '누가',
  EntryField.amount => '금액',
  EntryField.title => '내용',
  EntryField.category => '분류',
  EntryField.paymentMethod => '결제수단',
  EntryField.card => '카드',
  EntryField.date => entryDateLabel(kind),
  EntryField.dueOn => '예정일',
  EntryField.memo => '메모',
};

/// 고치기 화면을 연 사이 상대가 같은 칸을 다르게 고쳤을 때 묻는 창. 칸마다 상대 값과 내 값을 보여준다.
///
/// '내 값으로 저장'은 겹친 칸도 내 값으로, '상대 값 유지'는 겹친 칸만 상대 값으로 두고 나머지 내 변경을 저장한다.
/// 겹치지 않은 칸은 어느 쪽이든 합쳐진다(내가 바꾼 칸은 내 값, 상대만 바꾼 칸은 상대 값).
class EditConflictDialog extends ConsumerWidget {
  const EditConflictDialog({required this.conflict, super.key});

  final EntryEditConflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final methods = ref.watch(paymentMethodsProvider).value ?? const [];
    final kind = conflict.mine.kind;
    String dateOf(DateTime date) => '${date.month}월 ${date.day}일';
    String valueOf(EntryDraft draft, EntryField field) => switch (field) {
      EntryField.member => switch (MemberSlot.values
          .where((slot) => slot.name == draft.memberId)
          .firstOrNull) {
        final slot? => memberIn(members, slot).name,
        null => draft.memberId,
      },
      EntryField.amount => switch (draft.amount) {
        final amount? => won(amount),
        null => '금액 미정',
      },
      EntryField.title => draft.title.isEmpty ? '없음' : draft.title,
      EntryField.category =>
        categories.where((c) => c.id == draft.categoryId).firstOrNull?.name ??
            '없음',
      EntryField.paymentMethod =>
        methods.where((m) => m.id == draft.paymentMethodId).firstOrNull?.name ??
            '없음',
      EntryField.card =>
        methods.where((m) => m.id == draft.cardId).firstOrNull?.name ?? '없음',
      EntryField.date => switch (draft.date) {
        final date? => dateOf(date),
        null => switch (kind) {
          EntryKind.planned => '지급 전',
          EntryKind.fixedIncome => '받기 전',
          _ => '없음',
        },
      },
      EntryField.dueOn => switch (draft.dueOn) {
        final date? => dateOf(date),
        null => '없음',
      },
      EntryField.memo => draft.memo ?? '없음',
    };
    final muted = theme.textTheme.labelMedium;
    return AlertDialog(
      key: const Key('edit-conflict'),
      title: Text(keepAll('그사이 상대가 같은 칸을 바꿨어요')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            for (final field in EntryField.values)
              if (conflict.fields.contains(field))
                Column(
                  key: ValueKey('conflict-${field.name}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      editFieldLabel(field, kind),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '상대 · ${valueOf(conflict.theirs, field)}',
                      key: ValueKey('conflict-${field.name}-theirs'),
                      style: muted,
                    ),
                    Text(
                      '나 · ${valueOf(conflict.mine, field)}',
                      key: ValueKey('conflict-${field.name}-mine'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('conflict-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('conflict-theirs'),
          onPressed: () => Navigator.of(context).pop(EditConflictChoice.theirs),
          child: const Text('상대 값 유지'),
        ),
        TextButton(
          key: const Key('conflict-mine'),
          onPressed: () => Navigator.of(context).pop(EditConflictChoice.mine),
          child: const Text('내 값으로 저장'),
        ),
      ],
    );
  }
}
