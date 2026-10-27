import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 지금 시각. 테스트에서 날짜를 고정하려고 공급자로 둔다. UseCase 홀더도 이 값으로 시간을 받는다.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
