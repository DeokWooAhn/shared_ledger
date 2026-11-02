import 'package:flutter/material.dart';

import '../../domain/model/ledger_entries.dart';
import '../../core/widget/entry_kind_label.dart';
import '../../core/widget/keep_all.dart';

/// 종류 고르기 시트의 짧은 설명.
String entryKindDescription(EntryKind kind) => switch (kind) {
  EntryKind.income => '용돈·환급처럼 그때그때 들어온 돈',
  EntryKind.fixedIncome => '월급처럼 매달 들어오는 돈',
  EntryKind.planned => '관리비·보험처럼 매달 나가는 돈',
  EntryKind.extra => '그때그때 쓴 돈',
  EntryKind.cardBill => '지난달 카드값이 빠져나간 돈',
};

/// 입력 화면 맨 위의 종류 칸. 누르면 종류 고르기 시트([showEntryKindSheet])가 뜬다.
///
/// [onTap]이 null이면 고를 수 없다(고치기 화면은 종류를 바꾸지 못한다). 칸 전체가 하나의 버튼이라 직접 알린다.
class EntryKindField extends StatelessWidget {
  const EntryKindField({required this.kind, required this.onTap, super.key});

  final EntryKind kind;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = entryKindLabel(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        ExcludeSemantics(child: Text('종류', style: theme.textTheme.labelMedium)),
        Semantics(
          container: true,
          button: onTap != null,
          label: '종류',
          value: label,
          child: InkWell(
            key: const Key('entry-kind'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: InputDecorator(
              decoration: InputDecoration(
                enabled: onTap != null,
                suffixIcon: onTap == null
                    ? null
                    : const ExcludeSemantics(
                        child: Icon(Icons.keyboard_arrow_down, size: 22),
                      ),
              ),
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 종류를 고르는 시트를 띄우고 고른 종류를 돌려준다. 고르지 않고 닫으면 null.
Future<EntryKind?> showEntryKindSheet(
  BuildContext context, {
  required EntryKind selected,
}) => showModalBottomSheet<EntryKind>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _EntryKindSheet(selected: selected),
);

/// 종류 고르기 시트(design/app/05c). 수입·지출·카드로 묶어 이름과 짧은 설명을 보여준다.
class _EntryKindSheet extends StatelessWidget {
  const _EntryKindSheet({required this.selected});

  final EntryKind selected;

  static const _groups = [
    ('수입', [EntryKind.fixedIncome, EntryKind.income]),
    ('지출', [EntryKind.planned, EntryKind.extra]),
    ('카드', [EntryKind.cardBill]),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('무엇을 적을까요?', style: theme.textTheme.titleMedium),
            ),
            for (final (group, kinds) in _groups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 2),
                child: Text(group, style: theme.textTheme.labelMedium),
              ),
              for (final (index, kind) in kinds.indexed) ...[
                if (index > 0)
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                _KindOption(
                  key: Key('entry-kind-${kind.name}'),
                  kind: kind,
                  selected: kind == selected,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 종류 한 줄. 고른 종류는 강조하고 체크를 붙인다. 누르면 그 종류를 돌려주며 시트가 닫힌다.
class _KindOption extends StatelessWidget {
  const _KindOption({required this.kind, required this.selected, super.key});

  final EntryKind kind;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(kind),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        entryKindLabel(kind),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: selected ? scheme.primary : null,
                        ),
                      ),
                      Text(
                        keepAll(entryKindDescription(kind)),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (selected)
                  ExcludeSemantics(
                    child: Icon(Icons.check, color: scheme.primary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
