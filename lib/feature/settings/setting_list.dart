import 'package:flutter/material.dart';

import '../../core/widget/keep_all.dart';
import '../../core/widget/tab_page.dart';

// 설정 탭과 분류·결제수단 목록 화면이 같이 쓰는 카드·줄. 디자인은 design/app/07.

/// 설정 탭에서 들어가는 목록 화면의 머리말. 뒤로 가기 단추 아래에 제목과 설명을 둔다.
class SubPageTitle extends StatelessWidget {
  const SubPageTitle(this.title, {this.description, super.key});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton(
            key: const Key('sub-page-back'),
            tooltip: '설정으로 돌아가기',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              fixedSize: const Size(40, 40),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
        ),
        TabTitle(title, description: description),
      ],
    );
  }
}

/// 제목이 있는 설정 묶음 카드. 줄 사이에 구분선을 넣는다.
class SettingCard extends StatelessWidget {
  const SettingCard({
    required this.children,
    this.title,
    this.footer = const [],
    super.key,
  });

  final String? title;
  final List<Widget> children;

  /// 줄 아래에 구분선 없이 붙일 것(단추·안내).
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = this.title;
    final divider = Divider(height: 1, color: theme.colorScheme.outline);
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, title == null ? 4 : 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.labelMedium),
              ),
              const SizedBox(height: 4),
            ],
            for (final (index, child) in children.indexed) ...[
              if (index > 0) divider,
              child,
            ],
            ...footer,
          ],
        ),
      ),
    );
  }
}

/// 설정 한 줄: 아이콘 칸, 이름, 오른쪽 값, 누를 수 있으면 화살표.
class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.title,
    this.leading,
    this.value,
    this.trailing,
    this.badge,
    this.titleColor,
    this.onTap,
    super.key,
  });

  final String title;
  final Widget? leading;

  /// 오른쪽에 흐리게 보일 값. 예: '4개', 'Google'
  final String? value;

  /// 오른쪽 화살표 앞에 둘 것(역할 표시 등).
  final Widget? trailing;

  /// 이름 옆에 붙일 작은 표시(저축 등).
  final Widget? badge;
  final Color? titleColor;

  /// null이면 누를 수 없고 화살표도 없다(보기 전용).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leading = this.leading;
    final value = this.value;
    final trailing = this.trailing;
    final badge = this.badge;
    // 화면 읽기 도구가 이름·값·표시를 한 줄로, 누를 수 있으면 버튼으로 읽게 한다.
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                spacing: 14,
                children: [
                  ?leading,
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: titleColor,
                          ),
                        ),
                        ?badge,
                      ],
                    ),
                  ),
                  if (value != null)
                    Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ?trailing,
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 설정 줄 왼쪽의 둥근 사각 아이콘 칸.
class SettingIconTile extends StatelessWidget {
  const SettingIconTile(this.icon, {this.danger = false, super.key});

  final IconData icon;

  /// 위험한 동작(탈퇴 등)이면 오류 색으로 칠한다.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: danger ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 20,
        color: danger ? scheme.error : scheme.onSurface,
      ),
    );
  }
}

/// 이름 옆 작은 표시. 예: 역할(관리자), 저축
class SettingChip extends StatelessWidget {
  const SettingChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// 보기 전용 구성원에게 목록 위에 보여 주는 안내.
class ViewOnlyNotice extends StatelessWidget {
  const ViewOnlyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      key: const Key('view-only-notice'),
      spacing: 8,
      children: [
        Icon(
          Icons.visibility_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        Expanded(
          child: Text(
            keepAll('보기 전용이라 바꿀 수 없어요.'),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// 목록을 받는 중.
class SettingListLoading extends StatelessWidget {
  const SettingListLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('setting-list-loading'),
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 목록을 받지 못했을 때나 목록이 비었을 때의 안내 카드.
class SettingListMessage extends StatelessWidget {
  const SettingListMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Text(
          keepAll(message),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}
