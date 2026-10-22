import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widget/keep_all.dart';
import 'sign_in_controller.dart';

/// 로그인 화면(design/app.pen의 01). Apple 로그인은 iOS에서만 보여준다.
/// 카카오 로그인은 출시 준비 단계에서 붙인다. 로직은 [SignInController]에 있다.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  static const _padding = EdgeInsets.fromLTRB(24, 8, 24, 28);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signInControllerProvider);
    final controller = ref.read(signInControllerProvider.notifier);
    ref.listen(signInControllerProvider.select((s) => s.failed), (_, failed) {
      if (!failed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(keepAll('로그인하지 못했어요. 잠시 후 다시 시도해 주세요.'))),
      );
      controller.failureShown();
    });
    final showApple = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      // 디자인에서 로그인 화면만 카드색(흰색) 바탕이다.
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: _padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: max(
                      0,
                      constraints.maxHeight - _padding.vertical,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(child: _Hero()),
                        const SizedBox(height: 20),
                        if (showApple) ...[
                          FilledButton.icon(
                            key: const Key('sign-in-apple'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: state.busy
                                ? null
                                : () => controller.signIn(SignInMethod.apple),
                            icon: const Icon(Icons.apple),
                            label: const Text('Apple로 계속하기'),
                          ),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton(
                          key: const Key('sign-in-google'),
                          onPressed: state.busy
                              ? null
                              : () => controller.signIn(SignInMethod.google),
                          child: const Text('Google로 계속하기'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.tertiary,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: scheme.tertiary.withValues(alpha: 0.2),
                offset: const Offset(0, 10),
                blurRadius: 24,
              ),
            ],
          ),
          child: SizedBox.square(
            dimension: 84,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 40,
              color: scheme.onTertiary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          keepAll('심플 공유 가계부'),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 14),
        Text(
          keepAll('둘이 같이 쓰는 가계부'),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 46),
        const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ValuePoint(
              icon: Icons.people_outline,
              text: '한 사람이 적으면 바로 같이 보여요',
            ),
            SizedBox(height: 14),
            _ValuePoint(icon: Icons.repeat, text: '고정 지출은 매달 알아서 채워져요'),
            SizedBox(height: 14),
            _ValuePoint(
              icon: Icons.credit_card_outlined,
              text: '카드값은 다음 달 청구 예정까지 보여요',
            ),
          ],
        ),
      ],
    );
  }
}

class _ValuePoint extends StatelessWidget {
  const _ValuePoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(keepAll(text))),
      ],
    );
  }
}
