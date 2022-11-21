import 'package:intl/intl.dart';

mixin BeforeAfter<T> on Comparable<T> {
  bool isBefore(T other) {
    return compareTo(other) < 0;
  }

  bool isAfter(T other) {
    return compareTo(other) > 0;
  }

  bool isSame(T other) {
    return compareTo(other) == 0;
  }
}

class Date extends Comparable<Date> with BeforeAfter {
  /// `date` which time is noramlized to 00:00:00.
  /// `date` is always UTC
  final DateTime _date;

  Date._fromTime(DateTime time) : _date = _normalizeDate(time);

  Date._internal(DateTime normalizedDate) : _date = normalizedDate;

  factory Date.today() {
    return DateTime.now().date();
  }

  /// Normalize date's time to 00:00:00.
  /// `date` is always UTC
  static DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  int get year {
    return _date.year;
  }

  int get month {
    return _date.month;
  }

  int get day {
    return _date.day;
  }

  int get weekday {
    return _date.weekday;
  }

  Date add(int days) {
    final time = _date.add(Duration(days: days));

    assert(time.hour == 0);
    assert(time.minute == 0);
    assert(time.second == 0);

    return Date._internal(time);
  }

  Date substract(int days) {
    final time = _date.subtract(Duration(days: days));

    assert(time.hour == 0);
    assert(time.minute == 0);
    assert(time.second == 0);

    return Date._internal(time);
  }

  bool isSameDay(DateTime date) {
    return _date.year == date.year &&
        _date.month == date.month &&
        _date.day == date.day;
  }

  String format(DateFormat dateFormat) {
    return dateFormat.format(_date);
  }

  // startOfDay Datetime in local timezone
  DateTime startOfDay() {
    assert(_date.hour == 0);
    assert(_date.minute == 0);
    assert(_date.second == 0);

    return DateTime(_date.year, _date.month, _date.day);
  }

  // endOfDay Datetime in local timezone
  DateTime endOfDay() {
    assert(_date.hour == 0);
    assert(_date.minute == 0);
    assert(_date.second == 0);

    var time = DateTime(_date.year, _date.month, _date.day);
    time = time.add(const Duration(hours: 23, minutes: 59, seconds: 59));

    assert(time.hour == 23);
    assert(time.minute == 59);
    assert(time.second == 59);

    return time;
  }

  @override
  bool operator ==(Object other) {
    return other is Date && isSame(other);
  }

  @override
  int compareTo(Date other) {
    return _date.compareTo(other._date);
  }

  @override
  int get hashCode => _date.hashCode;
}

extension DateTimeExt on DateTime {
  Date date() {
    return Date._fromTime(this);
  }

  bool get isLocal {
    return !isUtc;
  }
}
