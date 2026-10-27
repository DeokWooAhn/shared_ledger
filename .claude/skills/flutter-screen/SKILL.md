---
name: flutter-screen
description: 심플 공유 가계부(shared_ledger)에 새 화면이나 기능을 추가하거나 화면 구조를 바꿀 때 쓴다. "초대 화면 만들어줘", "항목 입력 기능 추가해줘", "설정 화면 넣어줘", Notifier·UseCase 작성, 저장소·UseCase·공급자·경로 배선, Firestore 필드 변경, domain·data·core·feature 중 어디에 둘지가 해당된다. MVVM(View + Riverpod Notifier) 파일 구성, 정석 레퍼런스, UseCase·Notifier·View 뼈대, 레이어 배선 순서, Firestore 필드를 바꿀 때 같이 고칠 파일이 들어 있다.
---

# 화면 / MVVM / 레이어 배선

설명보다 아래 정석 레퍼런스를 먼저 읽고 그 구조를 그대로 따른다. 규칙의 원본은 AGENTS.md의 'Dart 작성 규칙', '화면·상태 작업', '데이터·Firestore 작업'이다.

MVVM의 ViewModel 역할은 Riverpod `Notifier`를 상속한 클래스가 맡고, 이름은 `XxxNotifier`다(2026-10-27, 그전에는 `XxxController`).
레이어(`domain`·`data`·`core`·`feature`)와 의존 규칙은 AGENTS.md '프로젝트 구조'의 표가 원본이고 `test/architecture_test.dart`가 검사한다.
Notifier는 저장소 대신 domain의 UseCase를 영역별 홀더로 부른다(AGENTS.md 'UseCase', 2026-10-27).
입력란의 `TextEditingController`와 헷갈리지 않게, 입력란 컨트롤러 변수는 `_name`·`_code`처럼 내용으로 짓는다.

## 화면 하나 = 파일 2개 (`lib/feature/<기능>/`)

| 파일 | 내용 | 정석 레퍼런스 |
| --- | --- | --- |
| `<이름>_notifier.dart` | 불변 State, `Notifier`, `NotifierProvider.autoDispose`, 화면용 문제·실패 enum | `lib/feature/ledger/ledger_start_notifier.dart` |
| `<이름>_screen.dart` | View 위젯, enum → 화면 문구 함수, 화면에서만 쓰는 상태(입력란 컨트롤러·폼 키) | `lib/feature/ledger/ledger_start_screen.dart` |

- 더 작은 예: 로그인(`lib/feature/auth/sign_in_*`), 시트(`lib/feature/settings/invite_*`, 입력란이 있는 시트는 `lib/feature/settings/category_sheet.dart` + `category_form_notifier.dart`)
- 무엇을 열지 인자를 받는 화면(새 항목·고칠 항목)은 `NotifierProvider.autoDispose.family`로, Notifier가 생성자로 인자를 받는다.
  인자 클래스는 `==`를 구현한다: `lib/feature/entries/entry_form_notifier.dart`(`EntryFormArgs`)
- Notifier가 맡을 동작이 없는 화면은 Notifier 없이 공급자만 읽는다: `lib/feature/settings/settings_screen.dart`, `lib/feature/summary/summary_screen.dart`(계산한 요약 `monthSummaryProvider`를 그린다)
- 같은 기능 안에서 함께 쓰는 문구·위젯은 그 기능 폴더에 둔다(`member_role_label.dart`). 기능을 넘어 쓰는 위젯·공급자는 `lib/core`로,
  화면과 상관없는 규칙(검사, 계산, 기본값)은 `lib/domain`으로 올린다.

## 탭 화면

홈은 탭 4개다(`HomeTab`: 요약·항목·고정 지출·설정). 틀은 `lib/feature/home/home_shell.dart`, 경로는 `lib/router.dart`의 `StatefulShellRoute.indexedStack`.

- 탭 화면은 `TabPage`(`lib/core/widget/tab_page.dart`)로 감싼다. 넓은 화면에서 본문을 가운데 두고, 좁은 화면에서 떠 있는 탭 막대만큼 아래 여백을 둔다.
  두 칸으로 놓는 탭은 `LayoutBuilder`로 칸 수를 정하고 `TabPage(maxWidth:)`를 넓힌다(월 요약: 본문 폭 840 이상이면 두 칸).
- 머리말은 달을 보는 탭이면 `MonthHeader`, 아니면 `TabTitle`이다. 예: `lib/feature/summary/summary_screen.dart`, `lib/feature/templates/templates_screen.dart`
- 보고 있는 달은 `selectedMonthProvider`를 읽는다(탭을 옮겨도 같은 달). 오늘 날짜가 필요하면 `clockProvider`.
  머리말로 오가는 달은 `ledgerMonthsProvider`(항목 있는 달 + 이번 달, 목록을 아직 모으지 않았으면 null)이고, 달력은 모든 달을 보여준다.
  새 항목을 더하는 쓰기는 `Ledger.needsToRecord(month)`로 그달을 가계부의 달 목록에 같이 더한다(`SaveEntryUseCase`, `docs/firestore.md`의 `months`).
- 두 사람 표시는 `MemberAvatar`, 이름은 `membersProvider`에서 꺼낸다.
- 탭을 더하거나 빼면 `HomeTab`과 router.dart의 `Routes.of`·`_tabScreen`을 같이 고친다(`switch`라 빠뜨리면 컴파일 에러).
- 폭 600 이상(`wideLayoutMinWidth`)에서는 아래 탭 막대 대신 옆 탭 막대(NavigationRail)가 나온다. 위젯 테스트는 두 배치를 다 본다.
- Android 뒤로가기(버튼·스와이프 동작)는 탭 틀의 `PopScope`(`_HomeBackHandler`)가 받는다. 요약이 아닌 탭의 첫 화면에서는 요약 탭으로 가고,
  요약 탭에서는 안내 뒤 2초(`homeExitWindow`) 안에 한 번 더 뒤로 가야 앱을 닫는다. 탭 안의 하위 화면과 탭 위로 연 화면은
  go_router가 안쪽 Navigator부터 닫아서 평소처럼 닫힌다. 테스트는 `tester.binding.handlePopRoute()`(`test/feature/home/home_back_test.dart`).
  뒤로가기는 스와이프 동작일 수도 있어서 문구에 '누르면'을 쓰지 않는다('한 번 더 뒤로 가면 앱이 종료돼요.').
- 탭 안에서 더 들어가는 화면(설정 → 분류·결제수단 목록, 휴지통, 변경 기록)은 그 탭 `GoRoute`의 하위 경로로 둔다(router.dart의 `_tabRoutes`). 탭 막대가 그대로 보이고,
  탭을 다시 누르면 탭 첫 화면으로 돌아온다. 머리말은 뒤로 가기 단추가 있는 `SubPageTitle`(`lib/feature/settings/setting_list.dart`).
- 탭 화면에서 여는 아래 시트는 `useRootNavigator: true`로 앱 맨 위에 띄운다. 기본값(탭의 navigator)이면 좁은 화면의 떠 있는 탭 막대가
  시트 아래쪽을 가린다(PR ⑤에서 초대 시트로 겪음). 설정 시트는 `showSettingSheet`(넓은 화면 560폭)를 쓴다.

## UseCase 뼈대 (`lib/domain/usecase/<영역>/`)

정석 레퍼런스: `lib/domain/usecase/settings/save_category_use_case.dart`(검사 + 추가/고치기 + 바뀐 것 없으면 건너뛰기),
홀더 `lib/domain/usecase/settings/settings_use_cases.dart`, 홀더 공급자 `lib/core/providers/usecases.dart`.

```dart
/// 무엇을 하는지, 검사에 걸리면 무엇을 돌려주는지, 어떤 실패를 던지는지 적는다.
class SaveXxxUseCase {
  const SaveXxxUseCase(this._xxx);

  final XxxRepository _xxx;                       // 저장소(와 시간 DateTime Function())는 생성자로

  Future<XxxProblem?> call({required String ledgerId, Xxx? editing, required String name, required String uid}) async {
    final problem = xxxProblemOf(name);             // Notifier도 먼저 부르는 domain 검사 함수를 다시 부른다
    if (problem != null) return problem;            // 검사에 걸리면 쓰지 않고 문제를 값으로
    if (editing == null) {
      await _xxx.add(…);
    } else if (/* 바뀐 것이 있으면 */) {
      await _xxx.update(…);
    }
    return null;                                    // 저장소 실패(XxxWriteException)는 그대로 던진다
  }
}

/// 영역 홀더. 필드 이름은 클래스 이름에서 UseCase를 뺀 것.
class XxxUseCases {
  XxxUseCases(XxxRepository xxx)
    : watchXxx = WatchXxxUseCase(xxx),
      saveXxx = SaveXxxUseCase(xxx);

  final WatchXxxUseCase watchXxx;
  final SaveXxxUseCase saveXxx;
}

// lib/core/providers/usecases.dart
final xxxUseCasesProvider = Provider<XxxUseCases>(
  (ref) => XxxUseCases(ref.watch(xxxRepositoryProvider)),
);
```

- UseCase 하나 = 파일 하나(`<이름>_use_case.dart`), 공개 메서드는 `call()` 하나. 구독은 `Watch…`(`Stream`), 순수 계산은 저장소 없이(`CalculateMonthSummaryUseCase`).
- 바로 답이 나오는 검사는 domain 함수(`categoryNameProblemOf`, `inviteCodeProblemOf`)로 두고 UseCase와 Notifier가 같이 부른다. UseCase에만 두면 '진행 중'을 거친 뒤에야 문제를 알게 된다.
- Riverpod·Flutter를 import하지 않는다. `AsyncValue` 묶기는 공급자에, 화면에 그리려고 묶는 일(`mergeActivities`)은 feature에 남긴다.
- 시간이 필요하면 생성자로 `DateTime Function() now`를 받고, 홀더 공급자가 `clockProvider`를 넣는다(`PurgeEntryUseCase`, `AddMonthUseCase`).
- 공급자가 판단만 UseCase에 맡길 때는 다른 공급자 값을 미리 읽어 넘기지 말고 꺼내는 함수(`MonthLedger? Function()`)를 넘긴다.
  UseCase가 꺼낼 때만 `ref.watch`가 불려서, 지금처럼 필요할 때만 구독한다(`plannedFillProvider` → `PlanMonthFillUseCase`).
- feature는 저장소 자리(`repositories.dart`)를 import할 수 없다. `test/architecture_test.dart`가 막는다.

## Notifier 뼈대

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

final xxxNotifierProvider =
    NotifierProvider.autoDispose<XxxNotifier, XxxState>(XxxNotifier.new);

/// 무엇을 하는 화면인지, 성공하면 어디로 가는지 적는다.
class XxxNotifier extends Notifier<XxxState> {
  @override
  XxxState build() => const XxxState();

  Future<void> doSomething(String input) async {
    if (state.busy) return;                         // 두 번 눌림 무시
    final problem = xxxProblemOf(input);            // 서버에 묻기 전 입력 검사(domain 함수)
    if (problem != null) {
      state = XxxState(problem: problem);
      return;
    }
    state = const XxxState(pending: XxxAction.something);
    try {
      final refused = await ref.read(xxxUseCasesProvider).saveXxx(…); // 저장소가 아니라 UseCase 홀더
      if (!ref.mounted) return;                     // 화면이 사라졌으면 끝
      state = XxxState(problem: refused);           // UseCase가 돌려준 문제(대개 null)
    } on SomeDomainException catch (e) {            // 처리할 실패만 골라서
      if (!ref.mounted) return;
      state = XxxState(failure: failureFrom(e.reason));
    } catch (e) {                                   // 예상 못 한 실패는 스낵바
      debugPrint('… 실패: $e');
      if (!ref.mounted) return;
      state = const XxxState(failure: XxxFailure.something);
    }
  }

  void failureShown() => state = XxxState(pending: state.pending, problem: state.problem);
}
```

- UseCase 홀더는 `ref.read(xxxUseCasesProvider)`로 메서드 안에서 꺼낸다. 저장소 공급자(`xxxRepositoryProvider`)는 읽지 않는다.
  로그인한 사용자는 `ref.read(authUserProvider).value`.
- 화면과 상관없는 검사·계산은 domain으로 올려 따로 테스트한다. 바로 답이 나오는 것은 domain 함수(`inviteCodeProblemOf`), 저장소를 부르는 것은 UseCase.
- 화면을 넘어 오래 살아야 하는 상태(예: 지금 보고 있는 달)는 `autoDispose`를 빼고 공급자로 둔다. 화면 하나의 상태만 Notifier에 둔다.

## View 뼈대

```dart
class XxxScreen extends ConsumerStatefulWidget { … } // 입력란 컨트롤러가 없으면 ConsumerWidget

@override
Widget build(BuildContext context) {
  final state = ref.watch(xxxNotifierProvider);
  final controller = ref.read(xxxNotifierProvider.notifier);
  ref.listen(xxxNotifierProvider.select((s) => s.failure), (_, failure) {
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
- 입력란 오류: 그 칸에서 끝나는 검사는 `Form` + `TextFormField.validator`, 서버 결과도 보여야 하는 칸은 `TextField` + `errorText`를 Notifier 상태로.
  둘을 한 칸에 섞지 않는다(`forceErrorText`와 `validate()`를 섞으면 실패 뒤 첫 누름이 무시된다).
- 입력란은 `LabeledField`로 이름표와 묶는다. 본문은 `ConstrainedBox(maxWidth: 440~560)`로 가운데 둔다.
- 뒤로 단추로 닫는 전체 화면 입력(항목·고정 지출)은 `lib/core/widget/form_parts.dart`의 `FormNavBar`(뒤로 단추·제목), `WonAmountField`(큰 금액 칸),
  `ChoiceGroup`·`ChoicePill`(고르기 단추)을 같이 쓴다. 테스트용 키는 화면이 넘긴다(`fieldKey`, `closeKey`, `noteKey`).
  - `LabeledField`(MergeSemantics) 안의 입력란에 `InputDecoration.suffix`·`suffixText`를 쓰지 않는다. 초점에 따라 나타났다 사라지면서
    semantics 단언(`node.isMergedIntoParent`)이 깨진다(Flutter 3.47, PR ③에서 겪음). 늘 보이는 `suffixIcon`이나 입력란 밖 글자로 둔다(`WonAmountField`).
  - 안에 따로 누를 단추가 있는 칸(날짜 칸의 '지우기')은 `LabeledField`로 합치지 않고 `Semantics(button:, label:, value:)`로 직접 알린다(`_DateField`).

## 레이어 배선 순서

1. **모델** — `lib/domain/model/<이름>.dart`. 순수 Dart, 불변. 역할·권한 판단과 도메인 제한은 모델에 둔다(`MemberRole.canWrite`, `Ledger.canInvite`).
2. **저장소 인터페이스** — `lib/domain/repository/<이름>_repository.dart`
   - `abstract interface class XxxRepository`, 쓰기 입력(Draft), 도메인 실패 enum + 예외(`JoinFailure`, `JoinLedgerException`)
   - Firebase 타입을 쓰지 않는다(domain은 패키지를 import하지 않는다)
3. **저장소 구현** — `lib/data/<영역>/firestore_<이름>_repository.dart`
   - `FirestoreXxxRepository implements XxxRepository`
   - 문서 ↔ 모델 변환, 쓰기 데이터는 최상위 함수로 뺀다(`newLedgerData`, `ledgerFromFirestore`, `joinLedgerUpdate`)
   - 처리할 `FirebaseException` 코드만 도메인 실패로 바꾸고 나머지는 다시 던진다. 시간·난수는 생성자로 주입(`now:`, `random:`)
4. **UseCase** — `lib/domain/usecase/<영역>/<이름>_use_case.dart`와 영역 홀더 `<영역>_use_cases.dart`. 위 'UseCase 뼈대'대로.
   검사 함수는 그 모델 파일(`lib/domain/model/`)에 둔다.
5. **공급자** — `lib/core/providers/repositories.dart`에 저장소 자리(구현을 모름), `lib/core/providers/usecases.dart`에 홀더 공급자,
   `lib/core/providers/providers.dart`에 구독 `StreamProvider`(홀더의 `watch…`를 부른다).
   로그인하지 않았으면 빈 값(`myLedgersProvider`). 구현은 `lib/di.dart`의 `repositoryOverrides()`에 넣는다.
6. **Notifier·View** — 위 뼈대대로.
7. **경로** — `lib/router.dart`의 `Routes`에 경로를 더하고 `GoRoute`를 등록한다. 탭이면 위 '탭 화면'을 따른다.
   로그인·가계부 상태에 따라 반드시 거쳐야 하는 화면이면 `AppGate`·`redirectFor`를 고치고 `test/router_test.dart`에 경우를 더한다.
   그 밖의 화면은 `context.push`/`context.go`로 이동한다.
   feature 화면이 다른 경로를 열어야 하면 `router.dart`를 import하지 않고, router.dart가 여는 함수를 넘겨준다
   (`EntriesScreen(openForm:)`, `HomeShell(onAddEntry:)`). 결과가 필요하면 `context.push<T>`의 결과로 받는다.
8. **가짜** — 새 저장소 인터페이스에는 `testing/fakes.dart`에 가짜를 만든다. 작성 기준은 testing 스킬.
9. **테스트** — 변환 함수 단위 테스트(`test/data/`), UseCase 테스트(`test/domain/usecase/`), Notifier 테스트, 화면 흐름 위젯 테스트. testing 스킬.
   새 패키지를 들였으면 `test/architecture_test.dart`의 허용 목록도 고친다.

## Firestore 필드·컬렉션을 바꿀 때

한 곳만 바꾸면 앱 테스트는 가짜 저장소로 통과해도 실제 Firestore는 쓰기를 거부한다. 아래를 같이 바꾼다.

- [ ] `firestore-tests/rules.test.js` (먼저 고친다)
- [ ] `firestore.rules`
- [ ] 앱의 쓰기 데이터 함수와 그 필드 목록 테스트
- [ ] 권한 판단을 바꿨으면 `lib/domain/model/ledger.dart`와 `test/domain/model/ledger_test.dart`
- [ ] `docs/firestore.md`
- [ ] 새 쿼리에 복합 색인이 필요하면 `firestore.indexes.json`
- [ ] 가짜 저장소가 같은 약속을 지키는지(`testing/fakes.dart`)
- [ ] 새 쓰기면 변경 기록을 같은 일괄 쓰기·트랜잭션으로 남기는지(`lib/data/activity/firestore_activity_repository.dart`의 `addActivity`·`newActivityData`, 요약은 `lib/domain/activity/activity_summary.dart`). 가짜도 `logActivity`로 같은 요약을 남긴다

리스너는 필요한 문서만 구독한다. 규칙 배포는 PR이 합쳐진 뒤에 한다(firebase 스킬).

## 마치기 전에

- [ ] 여러 단어로 된 문장에 `keepAll()`, 테스트에서 찾을 위젯에 `Key`, 입력란에 `LabeledField`
- [ ] 반환된 `Future`를 버린 곳이 없는지, `await` 뒤 `ref.mounted`·`mounted`를 확인했는지
- [ ] verification 스킬대로 검사하고, 새 화면은 기기나 시뮬레이터에서 한 번 띄워 본다
- [ ] `docs/plan.md`의 단계 상태가 바뀌었으면 고친다
