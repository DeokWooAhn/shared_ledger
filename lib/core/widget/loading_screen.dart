import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// 로그인·가구 정보를 불러오는 동안 보이는 화면. 가구를 불러오지 못하면 안내와 로그아웃 버튼을 보여준다.
class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(myHouseholdsProvider).hasError;
    return Scaffold(
      body: Center(
        child: failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '가구 정보를 불러오지 못했어요.\n잠시 후 다시 열어 주세요.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                    child: const Text('로그아웃'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
