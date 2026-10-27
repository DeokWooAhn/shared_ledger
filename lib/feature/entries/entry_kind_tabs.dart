import 'package:flutter/material.dart';

import '../../domain/model/ledger_entries.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widget/entry_kind_label.dart';

/// 네 종류 중 하나를 고르는 세그먼트. 항목 탭과 입력 화면 맨 위에 둔다.
///
/// [onSelect]가 null이면 고를 수 없다(고치기 화면은 종류를 바꾸지 못한다).
/// 디자인은 칸 높이가 38이지만, 누르는 곳이 48 이상이 되게 막대 높이 전체를 누를 수 있게 한다.
class EntryKindTabs extends StatelessWidget {
  const EntryKindTabs({required this.selected, this.onSelect, super.key});

  final EntryKind selected;
  final ValueChanged<EntryKind>? onSelect;

  /// 테스트에서 [kind] 칸을 찾을 키.
  static Key keyOf(EntryKind kind) => Key('entry-kind-${kind.name}');

  @override
  Widget build(BuildContext context) {
    final onSelect = this.onSelect;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.track,
        borderRadius: BorderRadius.circular(14),
      ),
      // 막대 높이가 정해져 있어 글자 크기 설정은 1.3배까지만 따른다(탭 막대와 같다).
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              for (final kind in EntryKind.values)
                Expanded(
                  child: _Segment(
                    key: keyOf(kind),
                    label: entryKindLabel(kind),
                    selected: kind == selected,
                    onTap: onSelect == null || kind == selected
                        ? null
                        : () => onSelect(kind),
                    enabled: onSelect != null || kind == selected,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.enabled,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final color = !enabled
        ? colors.textMuted
        : selected
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? colors.segmentOn : null,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
