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
- **실행하지 않은 검증을 통과했다고 말하지 않는다.** 돌리지 못했으면 무엇을 왜 못 돌렸는지와 돌려야 할 명령을 적는다.

## 작업 시작 메모

코드 변경을 요청받으면 관련 코드와 지침을 먼저 읽고, 구현 전에 다음을 짧게 정리한다.

- **목표:** 해결할 문제와 기대 동작
- **수정 범위:** 먼저 읽을 파일, 수정할 파일, 이번 작업에서 제외할 내용
- **검증:** 확인할 시나리오와 실행할 명령
- **완료 조건:** 어떤 결과가 확인되면 끝낼 수 있는지
- **불확실한 점:** 아직 확인하지 못한 원인이나 결정

작은 작업은 채팅에 5~10줄로 작성한다. 여러 계층에 걸친 작업이나 다른 채팅으로 넘길 작업은 작업별 메모 파일로 남기고 경로를 알린다.
기존 지침은 복사하지 않고 필요한 스킬·코드·문서 경로를 참조한다.
문제를 재현하거나 코드를 확인하기 전에 원인을 단정하지 않는다. 작업 중 범위나 검증 방법이 달라지면 메모도 갱신한다.
메모를 작성한 뒤에는 이 파일의 기존 확인·승인 규칙에 따라 진행한다. 이미 확인받은 계획이 있으면 메모에 반영하고 같은 내용을 다시 확인받지 않는다.
질문·설명·검토만 요청받은 경우에는 구현용 메모를 만들지 않는다.

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
- Firestore 보안 규칙을 넓히지 않는다. 바꿀 때는 규칙 테스트를 먼저 고치고, 같은 내용인 앱 쪽 권한 판단(`lib/domain/model/ledger.dart`)도 같이 맞춘다.
- 서버는 Firebase Blaze(종량제)만 쓴다. 고정 월 요금이 드는 서비스(Supabase Pro 등)는 제안하지 않는다.

## 프로젝트 구조

Flutter 공식 아키텍처 가이드(Compass 예제)처럼 패키지 하나 안에서 레이어를 폴더로 나눈다(2026-10-27).

```
lib/
  domain/               순수 Dart. Flutter·Firebase·Riverpod를 import하지 않는다
    model/                모델(가계부, 항목, 반복 설정, 설정 등)
    budget/               계산 규칙(월 요약)
    repository/           저장소 인터페이스, 도메인 실패(JoinFailure 등), 쓰기 입력(Draft), 기본 분류·결제수단
    usecase/<영역>/        UseCase(call() 하나짜리 클래스)와 영역별 묶음(홀더, SettingsUseCases 등)
    activity/             변경 기록 한 줄 요약 규칙
    format/               원 표기(won)
  data/<영역>/           domain의 저장소를 Firebase로 구현한다. Firestore 구현 + 문서 ↔ 모델 변환 함수
  core/                 여러 기능이 같이 쓰는 것. domain만 본다
    providers/            공급자: repositories.dart(저장소 자리), usecases.dart(UseCase 홀더), clock.dart(지금 시각),
                          providers.dart(로그인·가계부·보고 있는 달 같은 앱 공통 상태)
    theme/                design/app.pen 토큰으로 만든 테마
    widget/               공용 위젯과 화면 도우미(keepAll, signOutWithFeedback, MonthHeader)
  feature/<기능>/        화면: <이름>_screen.dart(View) + <이름>_notifier.dart(Notifier)
                          feature/home은 홈의 탭 틀(홈·내역·통계·설정)
  main.dart, app.dart   앱 시작점
  router.dart           화면 이동 규칙(go_router). feature 화면을 모은다
  di.dart               저장소 공급자에 Firebase 구현(data)을 넣는다. data를 아는 곳은 여기뿐이다
test/                   lib와 같은 구조 + architecture_test.dart(레이어 규칙 검사), 앱 전체 흐름 테스트
testing/                테스트에서만 쓰는 가짜 저장소와 도우미(fakes, provider_container, app). 배포하지 않는다
firestore.rules         보안 규칙. 테스트는 firestore-tests/
functions/              Cloud Functions(TypeScript). 공휴일 동기화(syncHolidays)와 구성원이 빈 가계부 지우기(deleteClosedLedger)
```

의존 방향은 한쪽으로만 흐른다(MVVM, 단방향 데이터 흐름).

```
feature ──→ core ──→ domain ←── data ←── 앱(main·di·router: 모두를 조립)
View(*_screen) ─→ Notifier(*_notifier) ─→ UseCase 홀더(core/providers/usecases.dart) ─→ UseCase(domain/usecase)
       └──────── State를 그린다 ←─────────┘                 ─→ 저장소 인터페이스(domain) ⇠ Firestore 구현(data, di.dart가 넣음)
```

| 레이어 | import해도 되는 것 | 패키지 |
| --- | --- | --- |
| `domain` | domain | 없음(`dart:`만) |
| `data` | domain, data | cloud_firestore, firebase_auth, google_sign_in, rxdart |
| `core` | domain, core | flutter, flutter_riverpod |
| `feature/<기능>` | domain, core, 자기 기능 폴더 | flutter, flutter_riverpod, go_router |
| 앱(lib 바로 아래) | 모두 | 모두 |

- **이 표는 `test/architecture_test.dart`가 검사한다.** 어기면 CI가 실패한다. 새 패키지를 들이면(먼저 승인) 허용 목록도 같이 고친다.
  표 밖의 규칙 하나도 같이 검사한다: feature는 저장소 자리(`core/providers/repositories.dart`)를 import하지 않고, 아무도 그것을 export하지 않는다.
- feature끼리 서로 import하지 않는다. 둘 이상이 쓰게 되면 core로, 규칙이면 domain으로 올린다.
- View와 Notifier는 저장소 구현(data)이나 Firebase를 볼 수 없다. Notifier와 공급자는 저장소도 직접 부르지 않고 UseCase 홀더를 부른다(아래 'UseCase').
- 어느 화면을 보여줄지는 `router.dart`의 `appGate`·`redirectFor`가 로그인·가계부 상태로 정한다. 화면에서 시작 화면들로 직접 이동하지 않는다.
- **컨셉은 커플·부부의 가계부다. 한 가계부에는 두 명까지 들어온다.** 이 제한은 보안 규칙(`maxMembers()`)과 앱(`ledgerMaxMembers`) 두 곳에 있어 같이 바꾼다.

### UseCase (`lib/domain/usecase/<영역>/`)

업무 규칙과 저장소 호출은 domain의 UseCase에 두고, Notifier는 UseCase만 부른다(2026-10-27). 뼈대와 예시는 flutter-screen 스킬.

- **UseCase 하나 = 파일 하나 = `call()` 하나짜리 클래스**(`save_category_use_case.dart`). 저장소와 시간(`DateTime Function() now`)은 생성자로 받는다. 순수 Dart다.
- **영역마다 홀더 하나**(`settings_use_cases.dart`의 `SettingsUseCases`)를 두고 홀더 공급자(`lib/core/providers/usecases.dart`)로 꺼낸다.
  영역: auth, ledger, settings, entry, month, template, activity, summary, holiday.
- **입력 검사처럼 바로 답이 나오는 규칙은 domain 함수**(`nameProblemOf`, `inviteCodeProblemOf`)다. Notifier가 먼저 부르고 쓰는 UseCase도 같은 함수로 다시 검사한다.
- 저장소의 실패(`SettingsWriteException` 등)는 UseCase가 그대로 던지고, 화면용 실패로 바꾸는 것은 Notifier다.
  입력란 문제로 보여 줄 것만 예외다 — `JoinLedgerUseCase`는 `JoinLedgerException`을 `InviteCodeProblem` 값으로 바꿔 돌려준다.

### 지금 쓰지 않는 것

들이려면 먼저 묻는다.

- 코드 생성(`build_runner`, freezed, json_serializable, riverpod_generator). 이유는 `docs/plan.md`의 결정 표
- 다른 상태 관리(Bloc, GetX, provider 패키지). 화면 상태는 Riverpod `Notifier`로 정했다(2026-10-21)
- 화면 위젯의 `setState`로 서버·공유 상태를 다루기. Notifier로 옮긴다
- HTTP 클라이언트와 로컬 DB. 앱은 Firestore만 쓰고, 오프라인은 Firestore 캐시로 처리한다
- 모킹 라이브러리(mockito, mocktail). `testing/fakes.dart`의 손으로 만든 가짜를 쓴다
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
  Notifier 메서드와 `signOutWithFeedback`처럼 안에서 오류를 모두 처리하는 함수는 버튼에서 바로 불러도 된다.
  `StreamSubscription`과 Notifier는 닫는 곳이 있어야 한다.
- **오류:** 빈 `catch`를 쓰지 않는다. 처리할 예외만 `on XxxException`으로 잡고 나머지는 다시 던진다.
  `Error`(StateError, TypeError 같은 프로그래머 오류)를 잡아 숨기지 않는다. 사용자가 취소한 것은 실패가 아니다(로그인은 false를 돌려준다).
  Notifier의 마지막 처리도 `catch (e)`가 아니라 `on Exception catch (e)`다(2026-11-06). 가짜 저장소는 예상 밖 실패를 `FakeFailure`(Exception)로 흉내 낸다.
  Riverpod은 공급자가 `Exception`으로 실패하면 최대 10번 다시 시도하고 `Error`는 다시 시도하지 않는다. 테스트는 `noRetry`로 끈다(`testing/provider_container.dart`).
- **실패는 문구가 아니라 값으로:** 저장소는 도메인 실패(`JoinFailure`)를, UseCase와 domain 검사는 입력 문제(`InviteCodeProblem`, `NameProblem`)를,
  Notifier는 화면용 실패(`LedgerStartFailure`)를 enum으로 넘긴다.
  화면 문구로 바꾸는 것은 View다(CalcMoney의 "UI 문자열 변환은 presentation에서"와 같다).
- **금액**은 원 단위 `int`다. `double`로 계산·저장하지 않는다.
- **시간·난수는 주입한다**(`FirestoreLedgerRepository(now:, random:)`, UseCase는 생성자의 `now`, 공급자·Notifier는 `clockProvider`). 안에서 `DateTime.now()`를 읽으면 테스트가 흔들린다.
- 저장소 인터페이스, Notifier의 공개 메서드, 공용 위젯에는 무엇을 하는지 한국어 문서 주석을 단다.

## 화면·데이터 작업

파일 구성, 뼈대, 정석 레퍼런스, 탭 화면, 테마·문구·접근성, Firestore를 바꿀 때 같이 고칠 파일은 **flutter-screen 스킬**에 있다.
여기에는 어기면 검사가 막거나 실제 Firestore가 거부하는 경계만 둔다.

- **화면 하나 = View(`<이름>_screen.dart`) + Notifier(`<이름>_notifier.dart`).** MVVM의 ViewModel 역할은 Riverpod `Notifier`가 맡는다
  (2026-10-27, 그전에는 `XxxController`). Flutter의 `TextEditingController`와 헷갈리지 않게 하려는 것이다.
- **Notifier와 공급자는 저장소를 직접 부르지 않고 UseCase 홀더를 부른다.** feature가 저장소 자리(`core/providers/repositories.dart`)를
  import하면 `test/architecture_test.dart`가 실패한다.
- **View는 State를 그리고 Notifier 메서드를 부르기만 한다.** `build` 안에서 저장소를 부르거나 상태를 바꾸거나 화면을 옮기거나 스낵바를 띄우지 않는다.
  `await` 뒤에는 `ref.mounted`·`context.mounted`를 확인한다.
- **어느 화면을 보여줄지는 `router.dart`의 `appGate`·`redirectFor`가 정한다.** 화면에서 시작 화면들로 직접 이동하지 않는다.
- **저장소 인터페이스와 도메인 실패는 `lib/domain/repository/`, Firestore 구현과 변환 함수는 `lib/data/<영역>/`에 둔다.**
  Firestore 타입(`DocumentSnapshot`, `Timestamp`)을 data 밖으로 내보내지 않고 모델로 바꿔 돌려준다.
- **쓰는 필드 = 보안 규칙이 받는 필드.** 한 곳만 바꾸면 앱 테스트는 가짜 저장소로 통과해도 실제 Firestore가 쓰기를 거부한다.
  같이 고칠 파일은 flutter-screen 스킬의 체크리스트를 따른다.

## 테스트와 검증

층별 작성법과 정석 레퍼런스는 **testing 스킬**, 명령·기기 실행·CI 실패 분석은 **verification 스킬**이다.

- Firebase를 모킹하지 않는다. 가짜 저장소는 실제 구현의 약속(두 명 제한, 취소는 false, 로그아웃이면 빈 목록)을 지킨다.
- 버그를 고치면 그 버그를 재현하는 테스트를 같이 넣는다.
- 작업을 마치기 전에 CI와 같은 검사(포맷·분석·테스트)를 돌린다.

## 환경 함정

코드만 봐서는 놓치기 쉬운 것들이다.

- **Flutter는 fvm으로 3.47.7에 고정돼 있다(`.fvmrc`).** 전역 Flutter(3.35.5) 대신 `fvm flutter`·`fvm dart`를 쓴다.
  전역 버전으로 한 번이라도 실행하면 빌드가 실패하면서 `pubspec.lock`이 바뀌고, `ios/Flutter/*.xcconfig`에 Pods 줄이 생기고, `ios/Podfile`이 생긴다.
  그렇게 됐으면 셋 다 되돌리고 `fvm flutter pub get`을 다시 한다. Android Studio 설정은 README의 '시작하기'.
- iOS 의존성은 **Swift Package Manager만** 쓴다(CocoaPods·Podfile 없음). 생명주기는 UIScene(`SceneDelegate.swift`) 방식이다.
- **Firebase 패키지는 4.x 세대로 고정했다.** firebase_core 5는 google_sign_in_ios와 충돌해 iOS 빌드가 깨진다. 올리기 전에 firebase 스킬을 본다.
- 패키지 버전을 바꾼 뒤 Android 빌드에서 플러그인 클래스를 못 찾으면 캐시 문제다. `fvm flutter clean` 후 다시 빌드한다.
- **계산 규칙을 바꾸면 `test/domain/budget/sheet_golden_test.dart`가 계속 통과해야 한다.** 정답 숫자가 달라지는 변경이면 시트 수식과 어긋나는 게 의도한 것인지 먼저 확인한다.
- Riverpod 3에서 `ProviderListenable` 같은 일부 타입은 `package:flutter_riverpod/misc.dart`에 있다.

## 세부 문서

Claude Code는 아래 스킬을 필요할 때 알아서 불러온다. 스킬 자동 로드가 없는 에이전트는 해당 파일을 직접 읽는다.

| 상황 | 읽을 파일 |
| --- | --- |
| 새 화면·기능 추가, Notifier·UseCase 작성, 저장소·경로 배선, Firestore 필드 변경, 탭·테마·문구·접근성 | `.claude/skills/flutter-screen/SKILL.md` |
| 테스트 작성(단위·UseCase·Notifier·위젯·보안 규칙), 가짜 저장소 | `.claude/skills/testing/SKILL.md` |
| 검사 명령, 기기·에뮬레이터 실행, CI 실패 분석 | `.claude/skills/verification/SKILL.md` |
| Firebase 설정, 규칙 배포, 로그인 제공자, 패키지 버전 | `.claude/skills/firebase/SKILL.md` |
| 코드 리뷰, PR·diff 검토 | `.claude/skills/review/SKILL.md` |
| 결정 사항, 계산 규칙 정의, 단계별 진행 상황, 비용 | `docs/plan.md` |
| Firestore 컬렉션·필드·역할별 권한 | `docs/firestore.md` |
| 사람용 소개, 개발 환경 준비 | `README.md` |

Maestro E2E는 아직 없다(`.maestro/` 없음). 출시 준비 단계에서 smoke Flow부터 만든다.
