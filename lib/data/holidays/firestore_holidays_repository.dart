import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/holidays.dart';
import '../../domain/repository/holidays_repository.dart';

class FirestoreHolidaysRepository implements HolidaysRepository {
  FirestoreHolidaysRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<Holidays> watchYear(int year) => _db
      .collection('holidays')
      .doc('$year')
      .snapshots()
      .map((snapshot) => holidaysFromFirestore(snapshot.data()));
}

final _holidayKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// `holidays/{연도}` 문서를 공휴일 표로 바꾼다. 문서가 없거나 모양이 다르면 빈 해이고,
/// 날짜·이름이 이상한 줄은 건너뛴다.
Holidays holidaysFromFirestore(Map<String, Object?>? data) {
  if (data?['days'] case final Map<Object?, Object?> days) {
    return Holidays({
      for (final MapEntry(:key, :value) in days.entries)
        if (key is String &&
            _holidayKeyPattern.hasMatch(key) &&
            value is String &&
            value.trim().isNotEmpty)
          key: value.trim(),
    });
  }
  return const Holidays();
}
