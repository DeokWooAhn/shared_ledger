# 심플 공유 가계부 작업 지침

커플·부부가 함께 쓰는 가계부 앱이다. 구글 시트로 쓰던 공동 가계부를 Flutter + Firebase 앱으로 옮겨 공개 배포한다.
Claude Code는 `CLAUDE.md`를 통해 이 파일을 읽고, Codex 같은 다른 에이전트와 CodeRabbit은 이 파일을 직접 읽는다.

이 파일에는 매번 지켜야 하는 것만 둔다. 절차는 스킬에, 결정과 데이터 구조는 docs에 한 곳씩만 두고, 여기서는 가리키기만 한다.

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

## 보안·공개 저장소

- **공개 저장소다.** 실제 가계부 금액·이름·개인 이메일·실제 uid를 코드·테스트·문서·커밋에 넣지 않는다. 테스트 데이터는 가상으로 만든다.
- 키스토어, 비밀번호, 토큰, 개인 키를 커밋하지 않는다. Firebase 설정 파일은 비밀 값이 아니다.
- 로그와 Crashlytics에 금액·메모 같은 사용자 입력값과 개인 식별 정보를 남기지 않는다.
- Firestore 보안 규칙을 넓히지 않는다. 바꿀 때는 규칙 테스트를 먼저 고치고, 같은 내용인 앱 쪽 권한 판단(`lib/core/model/household.dart`)도 같이 맞춘다.
- 서버는 Firebase Blaze(종량제)만 쓴다. 고정 월 요금이 드는 서비스(Supabase Pro 등)는 제안하지 않는다.

## 구조

```
lib/
  main.dart, app.dart   앱 시작점
  router.dart           화면 이동 규칙(go_router). feature 화면을 모으는 곳이라 feature를 import해도 된다
  core/
    budget/, model/     계산 규칙과 모델. 순수 Dart
    data/               Firebase 저장소(로그인, 가계부)와 Riverpod 공급자
    widget/             여러 화면이 같이 쓰는 위젯
  feature/<기능>/        기능별 화면 (auth, household, …)
test/                   lib와 같은 구조. test/support/fakes.dart에 가짜 저장소
firestore.rules         보안 규칙. 테스트는 firestore-tests/
```

- feature끼리 서로 import하지 않는다. 둘 이상이 쓰게 되면 core로 올린다.
- `core/budget`, `core/model`에는 Flutter·Firebase import를 넣지 않는다.
- 화면은 Firebase 패키지를 직접 import하지 않고 `core/data`의 인터페이스(`AuthRepository`, `HouseholdRepository`)만 쓴다.
- 어느 화면을 보여줄지는 `router.dart`의 `appGate`·`redirectFor`가 로그인·가계부 상태로 정한다. 화면에서 시작 화면들로 직접 이동하지 않는다.
- **컨셉은 커플·부부의 가계부다.** 코드와 문서에 남은 '가구(household)'는 이전 컨셉의 이름이라 다음 작업에서 바꾼다.
  새 코드와 화면 문구에 '가구'를 더 늘리지 않는다.

### 지금 쓰지 않는 것

들이려면 먼저 묻는다.

- 코드 생성(`build_runner`, freezed, json_serializable, riverpod_generator)
- 다른 상태 관리(Bloc, GetX, provider 패키지)
- HTTP 클라이언트와 로컬 DB. 앱은 Firestore만 쓰고, 오프라인은 Firestore 캐시로 처리한다.

## 환경 함정

코드만 봐서는 놓치기 쉬운 것들이다.

- **Flutter는 fvm으로 3.47.7에 고정돼 있다(`.fvmrc`).** 전역 Flutter(3.35.5) 대신 `fvm flutter`·`fvm dart`를 쓴다.
  전역 버전으로 한 번이라도 실행하면 빌드가 실패하면서 `pubspec.lock`이 바뀌고, `ios/Flutter/*.xcconfig`에 Pods 줄이 생기고, `ios/Podfile`이 생긴다.
  그렇게 됐으면 셋 다 되돌리고 `fvm flutter pub get`을 다시 한다. Android Studio 설정은 README의 '시작하기'.
- iOS 의존성은 **Swift Package Manager만** 쓴다(CocoaPods·Podfile 없음). 생명주기는 UIScene(`SceneDelegate.swift`) 방식이다.
- **Firebase 패키지는 4.x 세대로 고정했다.** firebase_core 5는 google_sign_in_ios와 충돌해 iOS 빌드가 깨진다. 올리기 전에 firebase 스킬을 본다.
- 패키지 버전을 바꾼 뒤 Android 빌드에서 플러그인 클래스를 못 찾으면 캐시 문제다. `fvm flutter clean` 후 다시 빌드한다.
- **계산 규칙을 바꾸면 `test/core/budget/sheet_golden_test.dart`가 계속 통과해야 한다.** 정답 숫자가 달라지는 변경이면 시트 수식과 어긋나는 게 의도한 것인지 먼저 확인한다.
- 작업을 마치기 전에 CI와 같은 검사(포맷·분석·테스트)를 돌린다. 명령은 verification 스킬.

## 세부 문서

Claude Code는 아래 스킬을 필요할 때 알아서 불러온다. 스킬 자동 로드가 없는 에이전트는 해당 파일을 직접 읽는다.

| 상황 | 읽을 파일 |
| --- | --- |
| 검사 명령, 테스트 작성, 기기 실행, CI 실패 분석 | `.claude/skills/verification/SKILL.md` |
| 새 화면·기능 추가, Firestore 필드를 바꿀 때 같이 고칠 곳 | `.claude/skills/new-feature/SKILL.md` |
| Firebase 설정, 규칙 배포, 로그인 제공자, 패키지 버전 | `.claude/skills/firebase/SKILL.md` |
| 코드 리뷰, PR·diff 검토 | `.claude/skills/review/SKILL.md` |
| 결정 사항, 계산 규칙 정의, 단계별 진행 상황, 비용 | `docs/plan.md` |
| Firestore 컬렉션·필드·역할별 권한 | `docs/firestore.md` |
| 사람용 소개, 개발 환경 준비 | `README.md` |

Maestro E2E는 아직 없다(`.maestro/` 없음). 출시 준비 단계에서 smoke Flow부터 만든다.
