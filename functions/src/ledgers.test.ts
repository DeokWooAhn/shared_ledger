import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { becameEmpty, hasNoMembers } from './ledgers.js';

describe('becameEmpty', () => {
  test('혼자 쓰던 관리자가 나가 구성원이 비면 true', () => {
    assert.equal(becameEmpty({ memberUids: ['owner'] }, { memberUids: [] }), true);
  });

  test('관리자를 넘기거나 상대가 나가 한 명이 남으면 false', () => {
    assert.equal(becameEmpty({ memberUids: ['owner', 'partner'] }, { memberUids: ['partner'] }), false);
    assert.equal(becameEmpty({ memberUids: ['owner', 'partner'] }, { memberUids: ['owner'] }), false);
  });

  test('이름 바꾸기처럼 구성원이 그대로면 false', () => {
    assert.equal(becameEmpty({ memberUids: ['owner'] }, { memberUids: ['owner'] }), false);
  });

  test('이미 비어 있던 가계부를 다시 고쳤거나 목록이 없으면 false', () => {
    assert.equal(becameEmpty({ memberUids: [] }, { memberUids: [] }), false);
    assert.equal(becameEmpty(undefined, { memberUids: [] }), false);
    assert.equal(becameEmpty({ memberUids: ['owner'] }, {}), false);
    assert.equal(becameEmpty({ memberUids: ['owner'] }, undefined), false);
  });
});

describe('hasNoMembers', () => {
  test('구성원 목록이 비어 있을 때만 true', () => {
    assert.equal(hasNoMembers({ memberUids: [] }), true);
    assert.equal(hasNoMembers({ memberUids: ['owner'] }), false);
    // 문서가 이미 지워졌거나 목록이 없으면 지울 것이 없다.
    assert.equal(hasNoMembers(undefined), false);
    assert.equal(hasNoMembers({}), false);
  });
});
