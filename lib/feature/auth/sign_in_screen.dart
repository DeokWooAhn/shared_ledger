import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';

/// 로그인 화면. Apple 로그인은 iOS에서만 보여준다.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  Future<void> _signIn(Future<bool> Function() signIn) async {
    setState(() => _busy = true);
    try {
      await signIn();
      // 성공하면 화면 이동 규칙이 다음 화면으로 옮긴다. 취소하면 그대로 둔다.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
      debugPrint('로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authRepositoryProvider);
    final showApple = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                '심플 공유 가계부',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('가족과 함께 쓰는 가계부', textAlign: TextAlign.center),
              const Spacer(),
              if (showApple) ...[
                FilledButton.icon(
                  key: const Key('sign-in-apple'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy ? null : () => _signIn(auth.signInWithApple),
                  icon: const Icon(Icons.apple),
                  label: const Text('Apple로 계속하기'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                key: const Key('sign-in-google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _busy ? null : () => _signIn(auth.signInWithGoogle),
                child: const Text('Google로 계속하기'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
