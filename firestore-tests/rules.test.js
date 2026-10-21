// Firestore 보안 규칙 테스트. 에뮬레이터에서만 돈다 (demo- 프로젝트라 실제 프로젝트에 닿지 않음).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const OWNER = 'owner-uid';
const EDITOR = 'editor-uid';
const VIEWER = 'viewer-uid';
const OUTSIDER = 'outsider-uid';
const NEWCOMER = 'newcomer-uid';

const HOUSEHOLD = 'household-1';
const OTHER_HOUSEHOLD = 'household-2';
const MONTH = '2026-10';
const DAY = 24 * 60 * 60 * 1000;

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-shared-ledger',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

// 매 테스트마다: 가구1(관리자·편집자·보기 전용), 가구2(OUTSIDER가 관리자).
beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    await setDoc(householdRef(db), householdData(OWNER, { [EDITOR]: 'editor', [VIEWER]: 'viewer' }));
    await setDoc(householdRef(db, OTHER_HOUSEHOLD), householdData(OUTSIDER, {}));
  });
});

function firestoreAs(uid) {
  const context = uid ? env.authenticatedContext(uid) : env.unauthenticatedContext();
  return context.firestore();
}

function seed(callback) {
  return env.withSecurityRulesDisabled((context) => callback(context.firestore()));
}

function householdRef(db, id = HOUSEHOLD) {
  return doc(db, 'households', id);
}

function householdData(ownerUid, roles, name = '우리집') {
  return {
    name,
    ownerUid,
    roles,
    memberUids: [ownerUid, ...Object.keys(roles)],
    createdAt: Timestamp.fromMillis(0),
    updatedAt: Timestamp.fromMillis(0),
  };
}

function entryRef(db, { type = 'extras', id = 'entry-1', month = MONTH, household = HOUSEHOLD } = {}) {
  return doc(db, 'households', household, 'months', month, type, id);
}

function newEntry(uid, fields = {}) {
  return {
    memberId: 'member-a',
    title: '장보기',
    paymentMethodId: 'card',
    amount: 10000,
    createdBy: uid,
    updatedBy: uid,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...fields,
  };
}

function seedEntry(fields = {}) {
  return seed((db) =>
    setDoc(entryRef(db), {
      ...newEntry(EDITOR),
      createdAt: Timestamp.fromMillis(1000),
      updatedAt: Timestamp.fromMillis(1000),
      ...fields,
    }),
  );
}

function inviteRef(db, code) {
  return doc(db, 'invites', code);
}

function seedInvite(code, fields = {}) {
  return seed((db) =>
    setDoc(inviteRef(db, code), {
      householdId: HOUSEHOLD,
      role: 'editor',
      createdBy: OWNER,
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + 3 * DAY),
      ...fields,
    }),
  );
}

function joinUpdate(uid, role, code) {
  return {
    [`roles.${uid}`]: role,
    memberUids: arrayUnion(uid),
    inviteCode: code,
    updatedAt: serverTimestamp(),
  };
}

describe('가구 만들기와 읽기', () => {
  test('로그인하면 자기를 관리자로 하는 가구를 만들 수 있다', async () => {
    const db = firestoreAs(NEWCOMER);
    await assertSucceeds(
      setDoc(householdRef(db, 'new-household'), {
        name: '새 가구',
        ownerUid: NEWCOMER,
        roles: {},
        memberUids: [NEWCOMER],
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('다른 사람을 관리자로 하거나 구성원을 미리 넣어서 만들 수 없다', async () => {
    const db = firestoreAs(NEWCOMER);
    const base = {
      name: '새 가구',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };
    await assertFails(
      setDoc(householdRef(db, 'h-a'), { ...base, ownerUid: OUTSIDER, roles: {}, memberUids: [OUTSIDER] }),
    );
    await assertFails(
      setDoc(householdRef(db, 'h-b'), {
        ...base,
        ownerUid: NEWCOMER,
        roles: { [OUTSIDER]: 'editor' },
        memberUids: [NEWCOMER, OUTSIDER],
      }),
    );
  });

  test('로그인하지 않으면 가구를 만들 수 없다', async () => {
    await assertFails(
      setDoc(householdRef(firestoreAs(null), 'h-anon'), {
        name: '새 가구',
        ownerUid: 'anon',
        roles: {},
        memberUids: ['anon'],
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('구성원은 가구를 읽을 수 있고, 구성원이 아니면 읽을 수 없다', async () => {
    for (const uid of [OWNER, EDITOR, VIEWER]) {
      await assertSucceeds(getDoc(householdRef(firestoreAs(uid))));
    }
    await assertFails(getDoc(householdRef(firestoreAs(OUTSIDER))));
  });

  test('내가 속한 가구만 목록으로 조회할 수 있다', async () => {
    const db = firestoreAs(EDITOR);
    const mine = await assertSucceeds(
      getDocs(query(collection(db, 'households'), where('memberUids', 'array-contains', EDITOR))),
    );
    if (mine.size !== 1) throw new Error(`가구 1개를 기대했지만 ${mine.size}개`);
    await assertFails(getDocs(collection(db, 'households')));
  });
});

describe('구성원 관리', () => {
  test('관리자는 이름과 역할을 바꾸고 구성원을 내보낼 수 있다', async () => {
    const db = firestoreAs(OWNER);
    await assertSucceeds(
      updateDoc(householdRef(db), {
        name: '새 이름',
        [`roles.${VIEWER}`]: 'editor',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(householdRef(db), {
        [`roles.${VIEWER}`]: deleteField(),
        memberUids: arrayRemove(VIEWER),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('관리자도 구성원을 직접 추가할 수 없다 (초대로만)', async () => {
    await assertFails(
      updateDoc(householdRef(firestoreAs(OWNER)), {
        [`roles.${NEWCOMER}`]: 'editor',
        memberUids: arrayUnion(NEWCOMER),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('관리자를 늘리거나 관리자를 바꿀 수 없다', async () => {
    const db = firestoreAs(OWNER);
    await assertFails(
      updateDoc(householdRef(db), { [`roles.${EDITOR}`]: 'owner', updatedAt: serverTimestamp() }),
    );
    await assertFails(updateDoc(householdRef(db), { ownerUid: EDITOR, updatedAt: serverTimestamp() }));
  });

  test('편집자는 이름·역할을 바꾸거나 다른 구성원을 내보낼 수 없다', async () => {
    const db = firestoreAs(EDITOR);
    await assertFails(updateDoc(householdRef(db), { name: '바꾼 이름', updatedAt: serverTimestamp() }));
    await assertFails(
      updateDoc(householdRef(db), { [`roles.${VIEWER}`]: 'editor', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(householdRef(db), {
        [`roles.${VIEWER}`]: deleteField(),
        memberUids: arrayRemove(VIEWER),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('편집자와 보기 전용은 스스로 가구에서 나갈 수 있다', async () => {
    for (const uid of [VIEWER, EDITOR]) {
      await assertSucceeds(
        updateDoc(householdRef(firestoreAs(uid)), {
          [`roles.${uid}`]: deleteField(),
          memberUids: arrayRemove(uid),
          updatedAt: serverTimestamp(),
        }),
      );
    }
  });

  test('관리자만 가구를 삭제할 수 있다', async () => {
    await assertFails(deleteDoc(householdRef(firestoreAs(EDITOR))));
    await assertSucceeds(deleteDoc(householdRef(firestoreAs(OWNER))));
  });
});

describe('초대', () => {
  function newInvite(uid, fields = {}) {
    return {
      householdId: HOUSEHOLD,
      role: 'editor',
      createdBy: uid,
      createdAt: serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 3 * DAY),
      ...fields,
    };
  }

  test('관리자만 초대 코드를 만들 수 있다', async () => {
    await assertSucceeds(setDoc(inviteRef(firestoreAs(OWNER), 'INVITE0001'), newInvite(OWNER)));
    await assertFails(setDoc(inviteRef(firestoreAs(EDITOR), 'INVITE0002'), newInvite(EDITOR)));
  });

  test('유효기간은 7일을 넘길 수 없고, 너무 짧은 코드는 쓸 수 없다', async () => {
    const db = firestoreAs(OWNER);
    await assertFails(
      setDoc(
        inviteRef(db, 'INVITE0003'),
        newInvite(OWNER, { expiresAt: Timestamp.fromMillis(Date.now() + 8 * DAY) }),
      ),
    );
    await assertFails(setDoc(inviteRef(db, 'abc'), newInvite(OWNER)));
  });

  test('초대 코드로 초대에 적힌 역할로 참여할 수 있다', async () => {
    await seedInvite('JOINCODE01', { role: 'viewer' });
    await assertSucceeds(
      updateDoc(householdRef(firestoreAs(NEWCOMER)), joinUpdate(NEWCOMER, 'viewer', 'JOINCODE01')),
    );
  });

  test('초대보다 높은 역할로는 참여할 수 없다', async () => {
    await seedInvite('JOINCODE02', { role: 'viewer' });
    await assertFails(
      updateDoc(householdRef(firestoreAs(NEWCOMER)), joinUpdate(NEWCOMER, 'editor', 'JOINCODE02')),
    );
  });

  test('만료된 초대로는 참여할 수 없다', async () => {
    await seedInvite('JOINCODE03', { expiresAt: Timestamp.fromMillis(Date.now() - DAY) });
    await assertFails(
      updateDoc(householdRef(firestoreAs(NEWCOMER)), joinUpdate(NEWCOMER, 'editor', 'JOINCODE03')),
    );
  });

  test('다른 가구의 초대 코드로는 참여할 수 없다', async () => {
    await seedInvite('JOINCODE04', { householdId: OTHER_HOUSEHOLD, createdBy: OUTSIDER });
    await assertFails(
      updateDoc(householdRef(firestoreAs(NEWCOMER)), joinUpdate(NEWCOMER, 'editor', 'JOINCODE04')),
    );
  });

  test('초대 코드는 한 건씩만 읽을 수 있고 목록 조회는 막힌다', async () => {
    await seedInvite('JOINCODE05');
    const db = firestoreAs(NEWCOMER);
    await assertSucceeds(getDoc(inviteRef(db, 'JOINCODE05')));
    await assertFails(getDocs(collection(db, 'invites')));
  });

  test('관리자는 초대를 지울 수 있고, 다른 사람은 지울 수 없다', async () => {
    await seedInvite('JOINCODE06');
    await assertFails(deleteDoc(inviteRef(firestoreAs(EDITOR), 'JOINCODE06')));
    await assertSucceeds(deleteDoc(inviteRef(firestoreAs(OWNER), 'JOINCODE06')));
  });
});

describe('가계부 항목', () => {
  test('편집자는 항목을 추가하고, 관리자는 그 항목을 고칠 수 있다', async () => {
    await assertSucceeds(setDoc(entryRef(firestoreAs(EDITOR)), newEntry(EDITOR)));
    await assertSucceeds(
      updateDoc(entryRef(firestoreAs(OWNER)), {
        amount: 12000,
        updatedBy: OWNER,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('보기 전용은 항목을 읽을 수 있지만 쓸 수 없다', async () => {
    await seedEntry();
    const db = firestoreAs(VIEWER);
    await assertSucceeds(getDoc(entryRef(db)));
    await assertFails(setDoc(entryRef(db, { id: 'entry-2' }), newEntry(VIEWER)));
    await assertFails(
      updateDoc(entryRef(db), { amount: 1, updatedBy: VIEWER, updatedAt: serverTimestamp() }),
    );
  });

  test('다른 가구 사람은 항목을 읽을 수도 쓸 수도 없다', async () => {
    await seedEntry();
    const db = firestoreAs(OUTSIDER);
    await assertFails(getDoc(entryRef(db)));
    await assertFails(getDocs(collection(db, 'households', HOUSEHOLD, 'months', MONTH, 'extras')));
    await assertFails(setDoc(entryRef(db, { id: 'entry-2' }), newEntry(OUTSIDER)));
  });

  test('작성자와 시간을 위조할 수 없다', async () => {
    const db = firestoreAs(EDITOR);
    await assertFails(setDoc(entryRef(db), newEntry(EDITOR, { createdBy: OWNER })));
    await assertFails(setDoc(entryRef(db), newEntry(EDITOR, { createdAt: Timestamp.now() })));
  });

  test('고칠 때 처음 작성 기록을 바꾸거나 수정자를 남의 이름으로 둘 수 없다', async () => {
    await seedEntry();
    const db = firestoreAs(OWNER);
    await assertFails(
      updateDoc(entryRef(db), { createdBy: OWNER, updatedBy: OWNER, updatedAt: serverTimestamp() }),
    );
    await assertFails(updateDoc(entryRef(db), { amount: 5000, updatedAt: serverTimestamp() }));
  });

  test('금액은 0 이상의 정수여야 하고, 기본 월 지출만 비워 둘 수 있다', async () => {
    const db = firestoreAs(EDITOR);
    await assertFails(setDoc(entryRef(db, { id: 'a' }), newEntry(EDITOR, { amount: -1 })));
    await assertFails(setDoc(entryRef(db, { id: 'b' }), newEntry(EDITOR, { amount: '1000' })));
    await assertFails(setDoc(entryRef(db, { id: 'c' }), newEntry(EDITOR, { amount: 10.5 })));
    await assertFails(setDoc(entryRef(db, { id: 'd' }), newEntry(EDITOR, { amount: null })));
    await assertSucceeds(
      setDoc(entryRef(db, { type: 'planned', id: 'template-1' }), newEntry(EDITOR, { amount: null })),
    );
  });

  test('휴지통에 넣은 항목만 완전히 지울 수 있다', async () => {
    await seedEntry();
    const db = firestoreAs(EDITOR);
    await assertFails(deleteDoc(entryRef(db)));
    await assertSucceeds(
      updateDoc(entryRef(db), {
        deletedAt: serverTimestamp(),
        updatedBy: EDITOR,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(deleteDoc(entryRef(db)));
  });

  test('달 id가 yyyy-MM 형식이 아니면 항목을 만들 수 없다', async () => {
    const db = firestoreAs(EDITOR);
    await assertFails(setDoc(entryRef(db, { month: '2026-13' }), newEntry(EDITOR)));
    await assertFails(setDoc(entryRef(db, { month: '202610' }), newEntry(EDITOR)));
  });
});

describe('가구 설정과 변경 기록', () => {
  test('편집자는 분류를 만들 수 있고, 보기 전용은 만들 수 없다', async () => {
    const category = (uid) => ({
      name: '소비',
      countsAsSaving: false,
      createdBy: uid,
      updatedBy: uid,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(
      setDoc(doc(firestoreAs(EDITOR), 'households', HOUSEHOLD, 'categories', 'living'), category(EDITOR)),
    );
    await assertFails(
      setDoc(doc(firestoreAs(VIEWER), 'households', HOUSEHOLD, 'categories', 'saving'), category(VIEWER)),
    );
  });

  test('변경 기록은 자기 이름으로 추가만 할 수 있다', async () => {
    const db = firestoreAs(EDITOR);
    const ref = doc(db, 'households', HOUSEHOLD, 'activity', 'log-1');
    const log = (actorUid) => ({
      actorUid,
      at: serverTimestamp(),
      action: 'entry.create',
      summary: '추가지출 장보기 10,000원',
    });
    await assertFails(setDoc(doc(db, 'households', HOUSEHOLD, 'activity', 'log-0'), log(OWNER)));
    await assertSucceeds(setDoc(ref, log(EDITOR)));
    await assertFails(updateDoc(ref, { summary: '고친 기록' }));
    await assertFails(deleteDoc(ref));
  });
});
