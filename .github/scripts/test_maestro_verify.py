"""화면의 낙관적 저장과 서버 반영을 구분하고 검증을 생략하지 않는지 확인한다."""

import json
import subprocess
import unittest
from pathlib import Path


HARNESS = """
const fs = require('node:fs');
const vm = require('node:vm');
const options = JSON.parse(process.argv[2]);
const source = fs.readFileSync(process.argv[1], 'utf8');
const result = { output: { ledgerId: 'test-ledger' }, error: null };
const context = {
  output: result.output, json: JSON.parse, console: { log() {} },
  EXPECTED_TITLE: 'Test entry', EXPECTED_AMOUNT: '24600', EXPECTED_TRASHED: 'false',
  http: { get: () => ({ status: options.status || 200, body: JSON.stringify({ documents: options.docs }) }) }
};
try { vm.runInNewContext(source, context); } catch (e) { result.error = e.message; }
console.log(JSON.stringify(result));
"""


class MaestroVerifyTest(unittest.TestCase):
    def verify(self, docs, status=200):
        script = Path(__file__).resolve().parents[2] / '.maestro/scripts/verify_entry.js'
        result = subprocess.run(
            ['node', '-e', HARNESS, str(script), json.dumps(dict(docs=docs, status=status))],
            capture_output=True, text=True, check=True, timeout=10,
        )
        return json.loads(result.stdout)

    def document(self):
        return dict(name='test-ledger/extras/new-entry', fields=dict(
            title=dict(stringValue='Test entry'), amount=dict(integerValue='24600'),
            paymentMethodId=dict(stringValue='smoke-account'),
        ))

    def test_pending_server_write_is_not_verified(self):
        result = self.verify([])
        self.assertIsNone(result['error'])
        self.assertFalse(result['output']['entryVerified'])
        self.assertEqual(result['output']['entryVerifyState'], 'missing')
        self.assertNotIn('entryId', result['output'])

    def test_only_matching_server_fields_are_verified(self):
        result = self.verify([self.document()])
        self.assertTrue(result['output']['entryVerified'])
        self.assertEqual(result['output']['entryId'], 'new-entry')

    def test_field_mismatches_stay_unverified(self):
        for key, value, state in [
            ('amount', dict(integerValue='1'), 'amount-mismatch'),
            ('deletedAt', dict(timestampValue='2026-10-15T00:00:00Z'), 'trash-mismatch'),
            ('paymentMethodId', dict(stringValue='other-method'), 'method-mismatch'),
        ]:
            with self.subTest(key=key):
                doc = self.document()
                doc['fields'][key] = value
                result = self.verify([doc])
                self.assertFalse(result['output']['entryVerified'])
                self.assertEqual(result['output']['entryVerifyState'], state)

    def test_duplicates_and_http_errors_fail_immediately(self):
        duplicate = self.verify([self.document(), self.document()])
        self.assertIn('중복', duplicate['error'])
        failed = self.verify([], status=403)
        self.assertIn('HTTP 403', failed['error'])


if __name__ == '__main__':
    unittest.main()
