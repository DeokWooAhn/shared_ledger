---
name: flutter-screen
description: 심플 공유 가계부(shared_ledger)에 새 화면이나 기능을 추가하거나 화면 구조를 바꿀 때 쓴다. "초대 화면 만들어줘", "항목 입력 기능 추가해줘", "설정 화면 넣어줘", 컨트롤러 작성, 저장소·공급자·경로 배선, Firestore 필드 변경이 해당된다. MVVM(View + Riverpod Notifier 컨트롤러) 파일 구성, 정석 레퍼런스, 컨트롤러·View 뼈대, 레이어 배선 순서, Firestore 필드를 바꿀 때 같이 고칠 파일이 들어 있다.
---

# 화면 / MVVM / 레이어 배선

설명보다 아래 정석 레퍼런스를 먼저 읽고 그 구조를 그대로 따른다. 규칙의 원본은 AGENTS.md의 'Dart 작성 규칙', '화면·상태 작업', '데이터·Firestore 작업'이다.

MVVM의 ViewModel 역할은 Riverpod `Notifier`를 상속한 컨트롤러가 맡는다. Riverpod 관례대로 `XxxController`라고 부른다.
입력란의 `TextEditingController`와 헷갈리지 않게, 입력란 컨트롤러 변수는 `_name`·`_code`처럼 내용으로 짓는다.

## 화면 하나 = 파일 2개 (`lib/feature/<기능>/`)

| 파일 | 내용 | 정석 레퍼런스 |
| --- | --- | --- |
| `<이름>_controller.dart` | 불변 State, `Notifier` 컨트롤러, `NotifierProvider.autoDispose`, 화면용 문제·실패 enum | `lib/feature/ledger/ledger_start_controller.dart` |
| `<이름>_screen.dart` | View 위젯, enum → 화면 문구 함수, 화면에서만 쓰는 상태(입력란 컨트롤러·폼 키) | `lib/feature/ledger/ledger_start_screen.dart` |

- 더 작은 예: 로그인(`lib/feature/auth/sign_in_*`), 시트(`lib/feature/settings/invite_*`)
- 저장소를 부르는 동작이 없는 화면은 컨트롤러 없이 공급자만 읽는다: `lib/feature/settings/settings_screen.dart`, `lib/feature/summary/summary_screen.dart`(계산한 요약 `monthSummaryProvider`를 그린다)
- 같은 기능 안에서 함께 쓰는 문구·위젯은 그 기능 폴더에 둔다(`member_role_label.dart`). 기능을 넘어 쓰면 `lib/core`로 올린다.

## 탭 화면

홈은 탭 4개다(`HomeTab`: 요약·항목·고정 지출·설정). 틀은 `lib/feature/home/home_shell.dart`, 경로는 `lib/router.dart`의 `StatefulShellRoute.indexedStack`.

- 탭 화면은 `TabPage`(`lib/core/widget/tab_page.dart`)로 감싼다. 넓은 화면에서 본문을 가운데 두고, 좁은 화면에서 떠 있는 탭 막대만큼 아래 여백을 둔다.
  두 칸으로 놓는 탭은 `LayoutBuilder`로 칸 수를 정하고 `TabPage(maxWidth:)`를 넓힌다(월 요약: 본문 폭 840 이상이면 두 칸).
- 머리말은 달을 보는 탭이면 `MonthHeader`, 아니면 `TabTitle`이다. 예: `lib/feature/summary/summary_screen.dart`, `lib/feature/templates/templates_screen.dart`
- 보고 있는 달은 `selectedMonthProvider`를 읽는다(탭을 옮겨도 같은 달). 오늘 날짜가 필요하면 `clockProvider`.
- 두 사람 표시는 `MemberAvatar`, 이름은 `membersProvider`에서 꺼낸다.
- 탭을 더하거나 빼면 `HomeTab`과 router.dart의 `Routes.of`·`_tabScreen`을 같이 고친다(`switch`라 빠뜨리면 컴파일 에러).
- 폭 600 이상(`wideLayoutMinWidth`)에서는 아래 탭 막대 대신 옆 탭 막대(NavigationRail)가 나온다. 위젯 테스트는 두 배치를 다 본다.

## 컨트롤러 뼈대

```dart
/// 화면 상태. 문구는 넣지 않는다.
@immutable
class XxxState {
  const XxxState({this.pending, this.problem, this.failure});

  final XxxAction? pending;      // 진행 중인 동작. null이면 쉬는 중
  final XxxProblem? problem;     // 화면 안에 계속 보여 줄 문제(입력란 아래 안내 등)
  final XxxFailure? failure;     // 스낵바로 한 번 알릴 실패. 알린 뒤 failureShown()으로 끈다

  bool get busy => pending != null;

  @override
  bool operator ==(Object other) => …; // 모든 필드 비교
  @override
  int get hashCode => Object.hash(pending, problem, failure);
}

final xxxControllerProvider =
    NotifierProvider.autoDispose<XxxController, XxxState>(XxxController.new);

/// 무엇을 하는 화면인지, 성공하면 어디로 가는지 적는다.
class XxxController extends Notifier<XxxState> {
  @override
  XxxState build() => const XxxState();

  Future<void> doSomething(String input) async {
    if (state.busy) return;                         // 두 번 눌림 무시
    final problem = problemOf(input);               // 서버에 묻기 전 입력 검사
    if (problem != null) {
      state = XxxState(problem: problem);
      return;
    }
    state = const XxxState(pending: XxxAction.something);
    try {
      await ref.read(someRepositoryProvider).something(…);
      if (!ref.mounted) return;                     // 화면이 사라졌으면 끝
      state = const XxxState();
    } on SomeDomainException catch (e) {            // 처리할 실패만 골라서
      if (!ref.mounted) return;
      state = XxxState(problem: problemFrom(e.reason));
    } catch (e) {                                   // 예상 못 한 실패는 스낵바
      debugPrint('… 실패: $e');
      if (!ref.mounted) return;
      state = const XxxState(failure: XxxFailure.something);
    }
  }

  void failureShown() => state = XxxState(pending: state.pending, problem: state.problem);
}
```

- 저장소는 `ref.read(…Provider)`로 메서드 안에서 꺼낸다. 로그인한 사용자는 `ref.read(authUserProvider).value`.
- 순수 계산이 길어지면 컨트롤러 밖의 최상위 함수로 빼서 따로 테스트한다(`inviteCodeProblemOf`).
- 화면을 넘어 오래 살아야 하는 상태(예: 지금 보고 있는 달)는 `autoDispose`를 빼고 공급자로 둔다. 화면 하나의 상태만 컨트롤러에 둔다.

## View 뼈대

```dart
class XxxScreen extends ConsumerStatefulWidget { … } // 입력란 컨트롤러가 없으면 ConsumerWidget

@override
Widget build(BuildContext context) {
  final state = ref.watch(xxxControllerProvider);
  final controller = ref.read(xxxControllerProvider.notifier);
  ref.listen(xxxControllerProvider.select((s) => s.failure), (_, failure) {
    if (failure == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(keepAll(xxxFailureMessage(failure)))),
    );
    controller.failureShown();
  });
  final problem = state.problem;
  return Scaffold(
    …
    TextField(
      decoration: InputDecoration(
        errorText: problem == null ? null : keepAll(xxxProblemMessage(problem)),
      ),
      onChanged: (_) => controller.inputEdited(),
    ),
    FilledButton(
      key: const Key('do-something'),
      onPressed: state.busy ? null : () => controller.doSomething(_input.text),
      child: const Text('…'),
    ),
  );
}
```

- 화면 문구 함수는 View 파일의 최상위 함수로 둔다(`inviteCodeProblemMessage`). `switch` 식으로 모든 경우를 다룬다.
- 입력란 오류: 그 칸에서 끝나는 검사는 `Form` + `TextFormField.validator`, 서버 결과도 보여야 하는 칸은 `TextField` + `errorText`를 컨트롤러 상태로.
  둘을 한 칸에 섞지 않는다(`forceErrorText`와 `validate()`를 섞으면 실패 뒤 첫 누름이 무시된다).
- 입력란은 `LabeledField`로 이름표와 묶는다. 본문은 `ConstrainedBox(maxWidth: 440~560)`로 가운데 둔다.

## 레이어 배선 순서

1. **모델** — `lib/core/model/<이름>.dart`. 순수 Dart, 불변. 역할·권한 판단과 도메인 제한은 모델에 둔다(`MemberRole.canWrite`, `Ledger.canInvite`).
2. **저장소** — `lib/core/data/<이름>_repository.dart`
   - `abstract interface class XxxRepository` + `FirestoreXxxRepository`
   - 문서 ↔ 모델 변환, 쓰기 데이터는 최상위 함수로 뺀다(`newLedgerData`, `ledgerFromFirestore`, `joinLedgerUpdate`)
   - 도메인 실패는 enum + 예외(`JoinFailure`, `JoinLedgerException`). 처리할 `FirebaseException` 코드만 바꾸고 나머지는 다시 던진다
   - 시간·난수는 생성자로 주입(`now:`, `random:`)
3. **공급자** — `lib/core/data/providers.dart`에 저장소 `Provider`와 구독 `StreamProvider`. 로그인하지 않았으면 빈 값(`myLedgersProvider`).
4. **컨트롤러·View** — 위 뼈대대로.
5. **경로** — `lib/router.dart`의 `Routes`에 경로를 더하고 `GoRoute`를 등록한다. 탭이면 위 '탭 화면'을 따른다.
   로그인·가계부 상태에 따라 반드시 거쳐야 하는 화면이면 `AppGate`·`redirectFor`를 고치고 `test/router_test.dart`에 경우를 더한다.
   그 밖의 화면은 `context.push`/`context.go`로 이동한다.
6. **가짜** — 새 저장소 인터페이스에는 `test/support/fakes.dart`에 가짜를 만든다. 작성 기준은 testing 스킬.
7. **테스트** — 변환 함수 단위 테스트, 컨트롤러 테스트, 화면 흐름 위젯 테스트. testing 스킬.

## Firestore 필드·컬렉션을 바꿀 때

한 곳만 바꾸면 앱 테스트는 가짜 저장소로 통과해도 실제 Firestore는 쓰기를 거부한다. 아래를 같이 바꾼다.

- [ ] `firestore-tests/rules.test.js` (먼저 고친다)
- [ ] `firestore.rules`
- [ ] 앱의 쓰기 데이터 함수와 그 필드 목록 테스트
- [ ] 권한 판단을 바꿨으면 `lib/core/model/ledger.dart`와 `test/core/model/ledger_test.dart`
- [ ] `docs/firestore.md`
- [ ] 새 쿼리에 복합 색인이 필요하면 `firestore.indexes.json`
- [ ] 가짜 저장소가 같은 약속을 지키는지(`test/support/fakes.dart`)

리스너는 필요한 문서만 구독한다. 규칙 배포는 PR이 합쳐진 뒤에 한다(firebase 스킬).

## 마치기 전에

- [ ] 여러 단어로 된 문장에 `keepAll()`, 테스트에서 찾을 위젯에 `Key`, 입력란에 `LabeledField`
- [ ] 반환된 `Future`를 버린 곳이 없는지, `await` 뒤 `ref.mounted`·`mounted`를 확인했는지
- [ ] verification 스킬대로 검사하고, 새 화면은 기기나 시뮬레이터에서 한 번 띄워 본다
- [ ] `docs/plan.md`의 단계 상태가 바뀌었으면 고친다
