// 실제 reset.js를 실행해 관리자 픽스처 준비 뒤 인증 읽기를 검증한다.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../.maestro/scripts/reset.js'), 'utf8');

function execute({ denied = false, missing = false } = {}) {
  const documents = new Map();
  const reads = [];
  const response = (body, status = 200) => ({ status, body: JSON.stringify(body) });
  const context = {
    output: {}, json: JSON.parse, console: { log() {} },
    http: {
      delete: () => response({}),
      request(url, options) {
        assert.equal(options.headers.Authorization, 'Bearer owner');
        documents.set(url, JSON.parse(options.body));
        return response({});
      },
      post(url, options) {
        if (url.includes('accounts:signUp')) return response({ localId: 'test-user', idToken: 'test-token' });
        assert.equal(options.headers.Authorization, 'Bearer test-token');
        const query = JSON.parse(options.body).structuredQuery;
        reads.push({ url, query });
        if (denied) return response({ error: 'permission-denied' }, 403);
        const prefix = url.replace(/:runQuery$/, '') + '/' + query.from[0].collectionId + '/';
        return response(missing ? [] : [...documents]
          .filter(([name]) => name.startsWith(prefix) && !name.slice(prefix.length).includes('/'))
          .map(([name, document]) => ({ document: { name, ...document } })));
      },
    },
  };
  vm.runInNewContext(source, context);
  return reads;
}

test('홈의 모든 쿼리를 테스트 계정으로 읽은 뒤 준비를 마친다', () => {
  const reads = execute();
  assert.equal(reads.length, 8);
  assert.equal(reads[0].query.where.fieldFilter.op, 'ARRAY_CONTAINS');
  assert.equal(reads[0].query.where.fieldFilter.field.fieldPath, 'memberUids');
  assert.equal(reads[0].query.where.fieldFilter.value.stringValue, 'test-user');
});

test('인증 읽기가 거부되면 성공으로 처리하거나 재시도하지 않는다', () => {
  assert.throws(() => execute({ denied: true }), /HTTP 403/);
});

test('인증은 성공해도 픽스처가 없으면 준비 실패로 처리한다', () => {
  assert.throws(() => execute({ missing: true }), /테스트 읽기 준비 실패/);
});
