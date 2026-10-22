# 심플 공유 가계부 작업 지침

커플·부부가 함께 쓰는 가계부 앱이다. 구글 시트로 쓰던 공동 가계부를 Flutter + Firebase 앱으로 옮겨 공개 배포한다.
Claude Code는 `CLAUDE.md`를 통해 이 파일을 읽고, Codex 같은 다른 에이전트와 CodeRabbit은 이 파일을 직접 읽는다.

코드를 쓰기 전에 이 파일의 규칙을 따른다. 세부 절차와 정석 레퍼런스는 스킬에, 결정과 데이터 구조는 docs에 있다.

## 작업 방식

- 질문·검토·설명 요청에는 답만 한다. "고쳐줘", "만들어줘", "올려줘"처럼 변경을 요청받았을 때만 파일·Git·외부 시스템을 바꾼다.
- 여러 파일을 건드리는 작업은 바꿀 파일과 설계를 먼저 요약해 보여주고 확인을 받는다.
- 주변 코드의 이름·구조·주석 밀도를 따른다. 요청과 관계없는 파일을 포맷하거나 정리하지 않는다.
- 사용자가 만든 변경은 되돌리지 않고, 관계없는 변경은 커밋에 넣지 않는다.
- 패키지는 그 기능을 만드는 단계에서 추가한다. 새 패키지는 목적·대안·앱 크기 영향을 설명하고 승인을 받은 뒤 넣는다.
- 주석·문서·테스트 설명·커밋 메시지·화면 문구는 한국어, 코드 식별자는 영어로 쓴다.

## 브랜치·커밋·PR

- `main`에 직접 커밋·푸시하지 않는다. 작업마다 브랜치를 만들고 PR로 합친다.
  - 브랜치 이름: `feature/…`, `fix/…`, `docs/…`, `chore/…` + 영어 소문자 하이픈 (`feature/partner-invite`)
  - PR은 CI가 통과한 뒤 squash merge한다. PR 제목이 그대로 `main`의 커밋 제목이 된다.
- 커밋 메시지와 PR 제목은 무엇을 했는지 한국어 문장으로 쓴다. 마침표는 붙이지 않는다.

```text
월 요약 화면에 카드 소계를 넣는다

- 필요하면 빈 줄 뒤에 바뀐 내용을 항목으로 적는다
```

- 커밋·PR에 AI 도구의 공동 작성자 표기(`Co-Authored-By` 등)를 붙이지 않는다.
- `--force` 푸시, `main` 기록 수정은 하지 않는다.

## 안전장치

- **`main` 보호** (GitHub ruleset "main 보호", 2026-10-22): PR로만, squash로만 합친다. CI 세 job(`Flutter 포맷·분석·테스트`,
  `Firestore 보안 규칙 테스트`, `Android 디버그 빌드`)이 통과하고 리뷰 대화가 모두 해결돼야 합칠 수 있다. 강제 푸시와 삭제는 막힌다.
  **CI job 이름을 바꾸면 ruleset의 필수 검사도 같이 고친다.** 안 그러면 그 이름의 검사가 오지 않아 모든 PR이 막힌다.
- **Claude Code 플러그인** (`.claude/settings.json`, ahn-cc-kit)
  - git-guard: 보호 브랜치(`main`, `master`, `release/*`)로 직접 푸시, `--force` 푸시, `reset --hard`·`clean -fd` 같은 되돌리기 어려운 명령을 실행 전에 막는다.
    이 폴더를 여러 세션이 함께 쓸 때 남의 작업을 지우지 않게 한다.
  - android-guard: Gradle wrapper 변조, Gradle 캐시 삭제, 서명 비밀값(`.jks`, `key.properties` 등) 읽기·쓰기를 막고, AndroidManifest의 노출 변경을 알린다.
    서명 없는 release 빌드 경고는 `gradlew …Release`만 보고 `flutter build appbundle`은 아직 못 잡는다.
  - 훅이 막으면 우회하지 말고 무엇이 왜 막혔는지 사용자에게 알린다.

## 보안·공개 저장소

- **공개 저장소다.** 실제 가계부 금액·이름·개인 이메일·실제 uid를 코드·테스트·문서·커밋에 넣지 않는다. 테스트 데이터는 가상으로 만든다.
- 키스토어, 비밀번호, 토큰, 개인 키를 커밋하지 않는다. Firebase 설정 파일은 비밀 값이 아니다.
- 로그와 Crashlytics에 금액·메모 같은 사용자 입력값과 개인 식별 정보를 남기지 않는다.
- Firestore 보안 규칙을 넓히지 않는다. 바꿀 때는 규칙 테스트를 먼저 고치고, 같은 내용인 앱 쪽 권한 판단(`lib/core/model/ledger.dart`)도 같이 맞춘다.
- 서버는 Firebase Blaze(종량제)만 쓴다. 고정 월 요금이 드는 서비스(Supabase Pro 등)는 제안하지 않는다.

## 프로젝트 구조

```
lib/
  main.dart, app.dart   앱 시작점
  router.dart           화면 이동 규칙(go_router). feature 화면을 모으는 조립 지점이라 feature를 import해도 된다
  core/
    budget/, model/     계산 규칙과 모델. 순수 Dart
    data/               저장소 인터페이스와 Firebase 구현, Riverpod 공급자
    theme/              design/app.pen 토큰으로 만든 테마
    widget/             여러 화면이 같이 쓰는 위젯과 화면 도우미(keepAll, signOutWithFeedback)
  feature/<기능>/        화면: <이름>_screen.dart(View) + <이름>_controller.dart(컨트롤러)
  feature/home/         홈의 탭 틀(요약·항목·고정 지출·설정). 탭 화면은 각자 feature 폴더에 있다
test/                   lib와 같은 구조. test/support/에 가짜 저장소와 ProviderContainer 도우미
firestore.rules         보안 규칙. 테스트는 firestore-tests/
```

의존 방향은 한쪽으로만 흐른다(MVVM, 단방향 데이터 흐름).

```
View(*_screen.dart) ─→ 컨트롤러(*_controller.dart) ─→ core/data(저장소·공급자) ─→ core/model·core/budget
         └──────────── State를 그린다 ←──────────────┘            └─→ Firebase
```

- feature끼리 서로 import하지 않는다. 둘 이상이 쓰게 되면 core로 올린다.
- `core/budget`, `core/model`에는 Flutter·Firebase import를 넣지 않는다.
- View와 컨트롤러는 Firebase 패키지를 직접 import하지 않고 `core/data`의 인터페이스(`AuthRepository`, `LedgerRepository`, `SettingsRepository`, `EntriesRepository`, `TemplatesRepository`)와 공급자만 쓴다.
- 어느 화면을 보여줄지는 `router.dart`의 `appGate`·`redirectFor`가 로그인·가계부 상태로 정한다. 화면에서 시작 화면들로 직접 이동하지 않는다.
- **컨셉은 커플·부부의 가계부다. 한 가계부에는 두 명까지 들어온다.** 이 제한은 보안 규칙(`maxMembers()`)과 앱(`ledgerMaxMembers`) 두 곳에 있어 같이 바꾼다.

### 지금 쓰지 않는 것

들이려면 먼저 묻는다.

- 코드 생성(`build_runner`, freezed, json_serializable, riverpod_generator)
- 다른 상태 관리(Bloc, GetX, provider 패키지). 화면 상태는 Riverpod `Notifier` 컨트롤러로 정했다(2026-10-21)
- 화면 위젯의 `setState`로 서버·공유 상태를 다루기. 컨트롤러로 옮긴다
- HTTP 클라이언트와 로컬 DB. 앱은 Firestore만 쓰고, 오프라인은 Firestore 캐시로 처리한다
- 모킹 라이브러리(mockito, mocktail). `test/support/fakes.dart`의 손으로 만든 가짜를 쓴다
- `dart:io`의 `Platform`(나중에 웹으로 Windows를 지원한다). `defaultTargetPlatform`을 쓴다
- `print`. 디버그 로그는 `debugPrint`이고, 금액·메모·이메일·토큰은 남기지 않는다
- 화면에서 색을 직접 쓰기(`Color(0xFF…)`, `Colors.red`, `AppPalette`). Apple 로그인 버튼의 검정·흰색만 예외

## Dart 작성 규칙

- **null 안전성:** `!`는 바로 위 코드가 null이 아님을 보장할 때만 쓴다. `late`는 초기화가 보장될 때만.
  `as`로 타입 검사를 건너뛰지 않는다. Firestore `Map` 값은 `is` 검사나 패턴으로 꺼낸다(`ledgerFromFirestore`).
- **불변:** 필드는 `final`, 생성자는 가능하면 `const`. 값으로 비교되는 모델·State는 `==`와 `hashCode`를 함께 구현한다(`SignInState`).
- **경우 나누기:** 정해진 몇 가지 경우는 `enum`이나 `sealed class`로 두고 `switch` 식으로 모든 경우를 다룬다.
  `default`·`_`를 쓰지 않아 경우가 늘면 컴파일 에러로 잡히게 한다(`InviteCodeProblem` → `inviteCodeProblemMessage`).
- 잠깐 묶어 돌려주는 값은 record, 이름이 붙는 개념은 클래스. 구현만 허용할 인터페이스는 `abstract interface class`.
- **비동기:** 오류가 날 수 있는 `Future`(저장소 호출 등)를 버리지 않는다. `await`하고, 기다리지 않는 것이 의도면 `unawaited(...)`로 드러낸다.
  컨트롤러 메서드와 `signOutWithFeedback`처럼 안에서 오류를 모두 처리하는 함수는 버튼에서 바로 불러도 된다.
  `StreamSubscription`과 컨트롤러는 닫는 곳이 있어야 한다.
- **오류:** 빈 `catch`를 쓰지 않는다. 처리할 예외만 `on XxxException`으로 잡고 나머지는 다시 던진다.
  `Error`(StateError, TypeError 같은 프로그래머 오류)를 잡아 숨기지 않는다. 사용자가 취소한 것은 실패가 아니다(로그인은 false를 돌려준다).
- **실패는 문구가 아니라 값으로:** 저장소는 도메인 실패(`JoinFailure`)를, 컨트롤러는 화면용 문제(`InviteCodeProblem`)를 enum으로 넘긴다.
  화면 문구로 바꾸는 것은 View다(CalcMoney의 "UI 문자열 변환은 presentation에서"와 같다).
- **금액**은 원 단위 `int`다. `double`로 계산·저장하지 않는다.
- **시간·난수는 주입한다**(`FirestoreLedgerRepository(now:, random:)`, 공급자·컨트롤러는 `clockProvider`). 안에서 `DateTime.now()`를 읽으면 테스트가 흔들린다.
- 저장소 인터페이스, 컨트롤러의 공개 메서드, 공용 위젯에는 무엇을 하는지 한국어 문서 주석을 단다.

## 화면·상태 작업 (MVVM)

새 화면을 만들 때는 flutter-screen 스킬의 순서와 정석 레퍼런스를 따른다.
MVVM의 ViewModel 역할은 Riverpod `Notifier`를 상속한 **컨트롤러**가 맡는다. 이름은 Riverpod 쪽 관례대로
`XxxController`, 파일은 `<이름>_controller.dart`, 공급자는 `xxxControllerProvider`로 짓는다(2026-10-21).

- **화면 하나 = View + 컨트롤러.** `ledger_start_screen.dart` + `ledger_start_controller.dart`가 정석이다.
  저장소를 부르는 동작이 없는 화면(`settings_screen.dart`: 시트 열기와 `signOutWithFeedback`만 씀)은 컨트롤러 없이 공급자만 읽는다.
- **컨트롤러**는 Riverpod `Notifier<불변 State>`이고 `NotifierProvider.autoDispose`로 만든다. 사용자 동작은 메서드로 받는다.
  `await` 뒤에는 `ref.mounted`를 확인한 뒤 상태를 바꾼다(화면이 사라지면 컨트롤러도 해제된다).
- **State**는 불변 클래스다. 진행 중인 동작(`pending`), 입력란 문제, 일회성 실패를 필드로 두고 화면 문구는 넣지 않는다.
- **View**는 State를 그리고 컨트롤러 메서드를 부르기만 한다. `build` 안에서 저장소를 부르거나 상태를 바꾸거나 화면을 옮기거나 스낵바를 띄우지 않는다.
  스낵바 같은 일회성 표시는 `ref.listen(provider.select(...))`으로 띄우고 컨트롤러의 `failureShown()`으로 끈다.
- 화면에서만 쓰는 상태(입력란 컨트롤러, 폼 키, '복사했어요' 표시)는 위젯에 두고 `dispose`에서 정리한다. 서버·공유 상태는 공급자와 컨트롤러에 둔다.
- 그릴 값은 `ref.watch`, 콜백에서 부를 컨트롤러·저장소는 `ref.read`로 꺼낸다. `build`에서 `ref.read`로 읽은 값을 그리면 갱신되지 않는다.
- **입력란 오류는 한 곳에서만 관리한다.** 그 칸 안에서 끝나는 검사는 폼 validator로(가계부 이름),
  서버 결과도 보여야 하는 칸은 입력 검사까지 컨트롤러 상태로(초대 코드) 한다. `Form.validate()`와 `forceErrorText`를 섞으면
  실패 뒤 첫 누름이 무시된다(PR #3에서 실제로 겪음).
- 진행 중에는 버튼을 막고(`state.busy`), 컨트롤러도 진행 중에 들어온 호출을 무시한다.
- 위젯 밖에서 `await`한 뒤 `BuildContext`를 쓰지 않는다. `await` 전에 `ScaffoldMessenger`를 잡아 두거나(`signOutWithFeedback`) `context.mounted`를 확인한다.
- 위젯을 돌려주는 private 메서드보다 작은 위젯 클래스로 나눈다(`_OptionCard`, `_ValuePoint`). 바뀌지 않는 위젯은 `const`.
- 긴 목록은 `ListView.builder`로 만들고, 항목에는 안정적인 id로 `ValueKey`를 준다. 인덱스를 키로 쓰지 않는다.
- **탭:** 홈은 탭 4개(`HomeTab`)이고 `StatefulShellRoute`가 탭마다 화면 상태를 지킨다. 탭 화면은 `TabPage`로 감싸고,
  달을 보는 탭은 `MonthHeader`를 머리말로 쓴다. 보고 있는 달은 `selectedMonthProvider` 하나를 모든 탭이 같이 읽는다.
- **넓은 화면:** 아이패드와 Mac(아이패드 앱)에서도 쓴다. 폭 600 이상이면 탭 막대가 옆(NavigationRail)으로 간다. 본문은 `ConstrainedBox(maxWidth: …)`로 가운데 두고,
  두 칸 배치는 `LayoutBuilder`로 바꾼다(`docs/plan.md`의 '화면'). 플랫폼 분기는 `defaultTargetPlatform`.
- **테마:** 색은 `Theme.of(context).colorScheme`과 `context.appColors`, 글자는 `textTheme`에서 꺼낸다(`lib/core/theme/app_theme.dart`, 원본은 `design/app.pen`). 화면 디자인은 `design/app/*.png`.
- **문구:** 해요체. 여러 단어로 된 문장(설명·안내·오류)은 `keepAll()`로 감싸고, 입력란 오류도 `errorText: keepAll(...)`로 넘긴다.
  Flutter는 한글을 단어 중간에서 줄바꿈한다. 저장하거나 비교하는 값에는 쓰지 않는다. '가구'·'가족' 대신 '가계부'·'두 사람'을 쓴다.
- **접근성:** 입력란은 `LabeledField`로 이름표와 묶어 화면 읽기 도구가 함께 읽게 한다. 아이콘만 있는 버튼에는 `tooltip`.
  누를 수 있는 것은 높이 48 이상(테마의 버튼은 54). 색만으로 뜻을 전하지 않는다.
- 테스트에서 찾을 위젯에는 `Key('kebab-case')`를 준다(`sign-in-google`, `join-ledger`).

## 데이터·Firestore 작업

- **저장소:** `abstract interface class XxxRepository`와 `FirestoreXxxRepository`를 한 파일에 둔다.
  Firestore 타입(`DocumentSnapshot`, `Timestamp`)은 저장소 밖으로 내보내지 않고 모델로 바꿔 돌려준다.
- 문서 ↔ 모델 변환은 최상위 순수 함수로 빼서 Firebase 없이 테스트한다(`newLedgerData`, `ledgerFromFirestore`, `joinLedgerUpdate`). 모르는 값은 앱을 죽이지 말고 건너뛴다.
- **쓰는 필드 = 보안 규칙이 받는 필드.** 필드·컬렉션을 바꿀 때 같이 고칠 파일은 flutter-screen 스킬의 체크리스트를 따른다.
- 시간 필드는 `FieldValue.serverTimestamp()`. 규칙이 `request.time`과 같은지 본다. 방금 쓴 문서는 서버 시간이 아직 null이다.
- **실패:** 저장소는 처리할 `FirebaseException` 코드만 도메인 실패로 바꿔 던지고 나머지는 다시 던진다. `permission-denied`를 빈 결과로 숨기지 않는다.
- 여러 문서를 함께 바꿔야 일관성이 맞으면 `WriteBatch`나 트랜잭션을 쓴다(가계부 + 기본 설정: `LedgerRepository.create`).
- **읽기는 곧 비용이다**(Firestore는 지출 한도 대상이 아님). 필요한 문서만 구독하고, 계속 늘어나는 목록(항목, 변경 기록)에는 `limit`이나 달 단위 범위를 두고,
  같은 쿼리는 공급자 하나를 여러 화면이 같이 읽는다.
- 오프라인에서는 보기와 새 항목 추가만 된다. 수정·삭제는 온라인에서만 한다(`docs/plan.md`).
- **공급자**(`lib/core/data/providers.dart`): 다른 공급자는 `ref.watch`로 의존한다. 로그인하지 않았으면 빈 값을 내보낸다.
  공급자 본문에서 쓰기 같은 부수효과를 일으키지 않는다.

## 테스트와 검증

작성법과 정석 레퍼런스는 testing 스킬, 명령·기기 실행·CI는 verification 스킬.

| 대상 | 테스트 | 정석 레퍼런스 |
| --- | --- | --- |
| 계산 규칙·모델·변환 함수 | 단위 테스트 | `test/core/model/ledger_test.dart`, `test/core/data/ledger_repository_test.dart` |
| 컨트롤러 | `ProviderContainer` + 가짜 | `test/feature/ledger/ledger_start_controller_test.dart` |
| 화면 흐름·화면 이동 | 위젯 테스트 | `test/widget_test.dart`, `test/router_test.dart` |
| 보안 규칙 | 에뮬레이터 | `firestore-tests/rules.test.js` |

- Firebase를 모킹하지 않는다. 가짜 저장소는 실제 구현의 약속(두 명 제한, 취소는 false, 로그아웃이면 빈 목록)을 지킨다.
- 버그를 고치면 그 버그를 재현하는 테스트를 같이 넣는다.
- 테스트 설명은 한국어로, 상황과 기대 결과가 드러나게 쓴다.
- 작업을 마치기 전에 CI와 같은 검사(포맷·분석·테스트)를 돌린다.

## 환경 함정

코드만 봐서는 놓치기 쉬운 것들이다.

- **Flutter는 fvm으로 3.47.7에 고정돼 있다(`.fvmrc`).** 전역 Flutter(3.35.5) 대신 `fvm flutter`·`fvm dart`를 쓴다.
  전역 버전으로 한 번이라도 실행하면 빌드가 실패하면서 `pubspec.lock`이 바뀌고, `ios/Flutter/*.xcconfig`에 Pods 줄이 생기고, `ios/Podfile`이 생긴다.
  그렇게 됐으면 셋 다 되돌리고 `fvm flutter pub get`을 다시 한다. Android Studio 설정은 README의 '시작하기'.
- iOS 의존성은 **Swift Package Manager만** 쓴다(CocoaPods·Podfile 없음). 생명주기는 UIScene(`SceneDelegate.swift`) 방식이다.
- **Firebase 패키지는 4.x 세대로 고정했다.** firebase_core 5는 google_sign_in_ios와 충돌해 iOS 빌드가 깨진다. 올리기 전에 firebase 스킬을 본다.
- 패키지 버전을 바꾼 뒤 Android 빌드에서 플러그인 클래스를 못 찾으면 캐시 문제다. `fvm flutter clean` 후 다시 빌드한다.
- **계산 규칙을 바꾸면 `test/core/budget/sheet_golden_test.dart`가 계속 통과해야 한다.** 정답 숫자가 달라지는 변경이면 시트 수식과 어긋나는 게 의도한 것인지 먼저 확인한다.
- Riverpod 3에서 `ProviderListenable` 같은 일부 타입은 `package:flutter_riverpod/misc.dart`에 있다.

## 세부 문서

Claude Code는 아래 스킬을 필요할 때 알아서 불러온다. 스킬 자동 로드가 없는 에이전트는 해당 파일을 직접 읽는다.

| 상황 | 읽을 파일 |
| --- | --- |
| 새 화면·기능 추가, 컨트롤러 작성, 저장소·경로 배선, Firestore 필드 변경 | `.claude/skills/flutter-screen/SKILL.md` |
| 테스트 작성(단위·컨트롤러·위젯·보안 규칙), 가짜 저장소 | `.claude/skills/testing/SKILL.md` |
| 검사 명령, 기기·에뮬레이터 실행, CI 실패 분석 | `.claude/skills/verification/SKILL.md` |
| Firebase 설정, 규칙 배포, 로그인 제공자, 패키지 버전 | `.claude/skills/firebase/SKILL.md` |
| 코드 리뷰, PR·diff 검토 | `.claude/skills/review/SKILL.md` |
| 결정 사항, 계산 규칙 정의, 단계별 진행 상황, 비용 | `docs/plan.md` |
| Firestore 컬렉션·필드·역할별 권한 | `docs/firestore.md` |
| 사람용 소개, 개발 환경 준비 | `README.md` |

Maestro E2E는 아직 없다(`.maestro/` 없음). 출시 준비 단계에서 smoke Flow부터 만든다.
