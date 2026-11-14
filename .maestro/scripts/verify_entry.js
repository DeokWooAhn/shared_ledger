// 화면이 바뀌었을 뿐 아니라 앱의 쓰기가 에뮬레이터 서버에 반영됐는지 확인한다.
var url = 'http://127.0.0.1:18080/v1/projects/demo-shared-ledger/databases/(default)/documents/ledgers/' + output.ledgerId + '/months/2026-10/extras';
var response = http.get(url, { headers: { Authorization: 'Bearer owner' } });
if (response.status !== 200) throw new Error('항목 읽기 실패: HTTP ' + response.status);
var docs = json(response.body).documents || [];
var found = docs.filter(function (doc) { return doc.fields.title.stringValue === EXPECTED_TITLE; });
if (found.length > 1) throw new Error('서버에 같은 테스트 항목이 중복 저장됐습니다.');
var doc = found[0];
var state = !doc ? 'missing'
  : Number(doc.fields.amount.integerValue) !== Number(EXPECTED_AMOUNT) ? 'amount-mismatch'
  : Boolean(doc.fields.deletedAt) !== (EXPECTED_TRASHED === 'true') ? 'trash-mismatch'
  : doc.fields.paymentMethodId.stringValue !== 'smoke-account' ? 'method-mismatch' : 'ready';
output.entryVerified = state === 'ready';
if (output.entryVerifyState !== state) {
  // 입력값은 기록하지 않고 누락·불일치 종류와 서버 문서 개수만 남긴다.
  var elapsed = Date.now() - (output.entryVerifyStartedAt || Date.now());
  console.log('MAESTRO_VERIFY state=' + state + ' documents=' + docs.length + ' elapsed_ms=' + elapsed);
  output.entryVerifyState = state;
}
if (output.entryVerified) output.entryId = doc.name.substring(doc.name.lastIndexOf('/') + 1);
