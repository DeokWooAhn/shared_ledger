// 화면이 바뀌었을 뿐 아니라 앱의 쓰기가 에뮬레이터 서버에 반영됐는지 확인한다.
var url = 'http://127.0.0.1:18080/v1/projects/demo-shared-ledger/databases/(default)/documents/ledgers/' + output.ledgerId + '/months/2026-10/extras';
var response = http.get(url, { headers: { Authorization: 'Bearer owner' } });
if (response.status !== 200) throw new Error('항목 읽기 실패: HTTP ' + response.status);
var docs = json(response.body).documents || [];
var found = docs.filter(function (doc) { return doc.fields.title.stringValue === EXPECTED_TITLE; });
if (found.length !== 1) throw new Error('기대한 항목이 하나가 아닙니다: ' + EXPECTED_TITLE);
var doc = found[0];
if (Number(doc.fields.amount.integerValue) !== Number(EXPECTED_AMOUNT)) throw new Error('서버의 금액이 다릅니다.');
if (Boolean(doc.fields.deletedAt) !== (EXPECTED_TRASHED === 'true')) throw new Error('서버의 휴지통 상태가 다릅니다.');
if (doc.fields.paymentMethodId.stringValue !== 'smoke-account') throw new Error('서버의 결제수단이 다릅니다.');
output.entryId = doc.name.substring(doc.name.lastIndexOf('/') + 1);
