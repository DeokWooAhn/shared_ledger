# Firestore 데이터 구조와 권한

규칙 원본은 [`firestore.rules`](../firestore.rules), 규칙 테스트는 [`firestore-tests/`](../firestore-tests).
이 문서와 규칙이 어긋나면 규칙이 기준이다.

## 역할

| 역할 | 누가 | 할 수 있는 것 |
|---|---|---|
| 관리자(owner) | 가계부를 만든 사람, 가계부마다 한 명 | 읽기·쓰기, 이름 변경, 구성원 역할 변경·내보내기, 초대 만들기·지우기, 가계부 삭제 |
| 편집자(editor) | 초대로 들어온 사람 | 읽기·쓰기, 스스로 나가기 |
| 보기 전용(viewer) | 초대로 들어온 사람 | 읽기, 스스로 나가기 |

- 커플·부부 가계부라 **한 가계부에는 두 명까지** 들어온다. 관리자 한 명과 초대로 들어온 한 명이다(규칙의 `maxMembers()`, 앱의 `ledgerMaxMembers`).
- 구성원은 **초대 코드로만** 들어온다. 관리자도 다른 사람을 직접 추가할 수 없다.
- 관리자는 자기 역할을 내려놓을 수 없다. 관리자 넘기기는 나중에 만든다.

## 컬렉션

```
ledgers/{ledgerId}
  members/{id}
  categories/{id}
  paymentMethods/{id}
  templates/{id}
  months/{yyyy-MM}/
    incomes/{id}
    planned/{templateId}
    extras/{id}
    cardBills/{id}
  activity/{id}
invites/{code}
```

### `ledgers/{ledgerId}`

| 필드 | 타입 | 설명 |
|---|---|---|
| `name` | string (1~40자) | 가계부 이름 |
| `ownerUid` | string | 관리자 uid |
| `roles` | map uid → `'editor'` \| `'viewer'` | 관리자를 뺀 구성원의 역할 |
| `memberUids` | list<string> | 관리자 + `roles`의 uid 전부. '내 가계부 목록' 조회(`array-contains`)용. 두 명까지 |
| `inviteCode` | string (선택) | 마지막으로 참여에 쓰인 초대 코드. 참여 규칙 확인용 |
| `createdAt`, `updatedAt` | timestamp | 서버 시간 |

`memberUids`는 항상 `ownerUid` + `roles`의 키와 같아야 하고, 규칙이 이를 확인한다.

### `invites/{code}`

문서 id가 초대 코드다. 앱이 추측하기 어려운 무작위 문자열로 만든다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `ledgerId` | string | 초대할 가계부 |
| `role` | `'editor'` \| `'viewer'` | 들어오면 받을 역할 |
| `createdBy` | string | 만든 관리자 uid |
| `createdAt` | timestamp | 서버 시간 |
| `expiresAt` | timestamp | 만든 때부터 7일 이내 |

- 코드를 아는 사람만 한 건씩 읽을 수 있고, 목록 조회는 막는다.
- 관리자만, 자리가 남은(혼자인) 가계부에만 만들 수 있다.
- 유효기간 안에는 다시 쓸 수 있지만, 가계부가 두 명으로 차면 더는 들어올 수 없다. 관리자가 지우면 바로 못 쓴다.

참여는 가계부 문서 하나를 고치는 것으로 한다(자리가 남아 있을 때만): `memberUids`에 자기 uid 추가, `roles`에 초대의 역할로 자기 추가, `inviteCode`에 코드, `updatedAt`에 서버 시간.

### 가계부 설정: `members`, `categories`, `paymentMethods`, `templates`

필드는 [`lib/core/model`](../lib/core/model)의 모델을 따른다. 규칙은 공통 기록 필드만 확인한다.

### 가계부 항목: `months/{yyyy-MM}/incomes|planned|extras|cardBills`

- 달 문서(`months/{yyyy-MM}`) 자체는 만들지 않고 하위 컬렉션만 쓴다. 달 id는 `2026-10` 형식이어야 한다.
- `planned`의 문서 id는 템플릿 id다. 두 사람이 동시에 그달을 처음 열어도 같은 문서를 만들어 중복이 생기지 않는다.
- `amount`: 0 이상의 정수(원). `planned`만 비어 있을 수 있다(금액 미정).
- `deletedAt`: 휴지통에 넣은 시간. 비어 있으면 정상 항목. **휴지통에 있는 항목만 완전히 지울 수 있다.**

### 공통 기록 필드 (설정·항목 모두)

| 필드 | 만들 때 | 고칠 때 |
|---|---|---|
| `createdBy` | 내 uid | 바꿀 수 없음 |
| `createdAt` | 서버 시간 | 바꿀 수 없음 |
| `updatedBy` | 내 uid | 내 uid |
| `updatedAt` | 서버 시간 | 서버 시간 |

앱에서는 시간 필드에 `FieldValue.serverTimestamp()`를 넣어야 규칙을 통과한다.

### `activity/{id}`: 변경 기록

| 필드 | 타입 | 설명 |
|---|---|---|
| `actorUid` | string | 바꾼 사람 (내 uid만 가능) |
| `at` | timestamp | 서버 시간 |
| `action` | string | 예: `entry.create`, `entry.trash` |
| `summary` | string | 화면에 보일 한 줄 |

추가만 가능하고 고치거나 지울 수 없다.

## 비용 메모

- 하위 컬렉션 규칙은 가계부 문서를 한 번 읽어 권한을 확인한다. 이 읽기도 Firestore 읽기 횟수에 들어간다.
- 가계부를 지워도 하위 컬렉션은 남는다. 정리는 나중에 함수나 앱에서 처리한다.
- 보기 전용 구성원은 그달의 기본 지출을 만들 수 없다. 편집자나 관리자가 먼저 그달을 열어야 생긴다.
