import '../../domain/model/ledger_entries.dart';

/// 화면에 보이는 항목 종류 이름. 항목 탭과 휴지통이 같이 쓴다.
String entryKindLabel(EntryKind kind) => switch (kind) {
  EntryKind.income => '수입',
  EntryKind.planned => '기본 지출',
  EntryKind.extra => '추가지출',
  EntryKind.cardBill => '카드대금',
};
