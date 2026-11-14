"""실제 Maestro 초기화 스크립트의 일시적 서버 실패와 재시도 한도를 검증한다."""

import json
import subprocess
import unittest
from pathlib import Path


HARNESS = """
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const responses = JSON.parse(process.argv[2]);
const options = JSON.parse(process.argv[3]);
const documents = new Map();
let deletes = 0;
let writes = 0;
let signups = 0;
let reads = 0;
let error = null;
const context = {
  console: { log() {} },
  json: JSON.parse,
  output: {},
  http: {
    delete(url) {
      if (url.endsWith('/documents')) {
        const status = responses[Math.min(deletes++, responses.length - 1)];
        return { status, body: status === 200 ? '{}' : '초기화 실패' };
      }
      return { status: 200, body: '{}' };
    },
    post(url, request) {
      if (url.includes('accounts:signUp')) {
        signups++;
        return { status: 200, body: '{"localId":"test-user","idToken":"test-token"}' };
      }
      reads++;
      assert.equal(request.headers.Authorization, 'Bearer test-token');
      const query = JSON.parse(request.body).structuredQuery;
      if (reads === 1) {
        assert.equal(query.where.fieldFilter.field.fieldPath, 'memberUids');
        assert.equal(query.where.fieldFilter.op, 'ARRAY_CONTAINS');
        assert.equal(query.where.fieldFilter.value.stringValue, 'test-user');
      }
      if (options.denied) return { status: 403, body: 'permission-denied' };
      const prefix = url.replace(/:runQuery$/, '') + '/' + query.from[0].collectionId + '/';
      const rows = options.missing ? [] : [...documents]
        .filter(([name]) => name.startsWith(prefix) && !name.slice(prefix.length).includes('/'))
        .map(([name, doc]) => ({ document: { name, ...doc } }));
      return { status: 200, body: JSON.stringify(rows) };
    },
    request(url, options) {
      assert.equal(options.headers.Authorization, 'Bearer owner');
      writes++;
      documents.set(url, JSON.parse(options.body));
      return { status: 200, body: '{}' };
    }
  }
};
try { vm.runInNewContext(fs.readFileSync(process.argv[1], 'utf8'), context); }
catch (e) { error = e.message; }
console.log(JSON.stringify({ deletes, writes, signups, reads, error }));
"""


class MaestroResetTest(unittest.TestCase):
    def run_reset(self, responses, **options):
        script = Path(__file__).resolve().parents[2] / '.maestro/scripts/reset.js'
        result = subprocess.run(
            ['node', '-e', HARNESS, str(script), json.dumps(responses), json.dumps(options)],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        )
        return json.loads(result.stdout)

    def test_success_prepares_fixture_once(self):
        """정상 초기화에서는 재요청 없이 픽스처를 만든다."""
        result = self.run_reset([200])
        self.assertEqual(result, dict(deletes=1, writes=7, signups=1, reads=8, error=None))

    def test_transient_server_error_retries_only_reset(self):
        """초기화의 일시적 서버 오류는 DELETE만 다시 요청한다."""
        result = self.run_reset([500, 200])
        self.assertEqual(result, dict(deletes=2, writes=7, signups=1, reads=8, error=None))

    def test_cancelled_listen_retries_only_reset(self):
        """실제 에뮬레이터의 CANCELLED에 해당하는 HTTP 499도 초기화만 재시도한다."""
        result = self.run_reset([499, 200])
        self.assertEqual(result, dict(deletes=2, writes=7, signups=1, reads=8, error=None))

    def test_denied_authenticated_read_fails_without_retry(self):
        """준비 단계의 인증 읽기를 거부하면 앱을 시작할 준비가 된 것으로 보지 않는다."""
        result = self.run_reset([200], denied=True)
        self.assertEqual(result['reads'], 1)
        self.assertEqual(result['deletes'], 1)
        self.assertIn('HTTP 403', result['error'])

    def test_missing_fixture_fails_readiness(self):
        """읽기에 성공해도 픽스처가 없으면 준비 실패다."""
        result = self.run_reset([200], missing=True)
        self.assertEqual(result['reads'], 1)
        self.assertIn('테스트 읽기 준비 실패', result['error'])

    def test_other_errors_fail_without_retry(self):
        """권한 오류 등 다른 실패는 재시도하거나 픽스처 생성으로 넘어가지 않는다."""
        result = self.run_reset([403, 200])
        self.assertEqual(result['deletes'], 1)
        self.assertEqual(result['writes'], 0)
        self.assertEqual(result['signups'], 0)
        self.assertIn('HTTP 403', result['error'])

    def test_persistent_server_error_fails_after_three_requests(self):
        """서버 오류가 계속되면 세 요청 뒤 실패를 그대로 드러낸다."""
        for status in (499, 500):
            with self.subTest(status=status):
                result = self.run_reset([status])
                self.assertEqual(result['deletes'], 3)
                self.assertEqual(result['writes'], 0)
                self.assertEqual(result['signups'], 0)
                self.assertIn(f'HTTP {status}', result['error'])


if __name__ == '__main__':
    unittest.main()
