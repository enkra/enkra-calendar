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
  /// `date` in UTC format, without its time part.
  final DateTime _date;

  Date.fromTime(DateTime time) : _date = _normalizeDate(time);

  Date._internal(DateTime normalizedDate) : _date = normalizedDate;

  /// Returns `date` in UTC format, without its time part.
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
    return Date._internal(time);
  }

  Date substract(int days) {
    final time = _date.subtract(Duration(days: days));
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

  DateTime utcTime() {
    return _date;
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

// Sunday as first day
class Week extends Comparable<Week> with BeforeAfter {
  // `sunday` of this week in UTC format, without its time part.
  final Date _sunday;

  Week.fromDate(Date date) : _sunday = _findSunday(date);

  Week._internal(Date sunday) : _sunday = sunday;

  static _findSunday(Date date) {
    final weekday = date.weekday;

    if (weekday == DateTime.sunday) {
      return date;
    } else {
      final sundayOfWeek = date.substract(weekday);
      return sundayOfWeek;
    }
  }

  Date firstDay() {
    return _sunday;
  }

  Date lastDay() {
    return _sunday.add(DateTime.daysPerWeek - 1);
  }

  @override
  int compareTo(Week other) {
    return _sunday.compareTo(other._sunday);
  }

  Week add(int weeks) {
    final newSunday = _sunday.add(DateTime.daysPerWeek * weeks);
    return Week._internal(newSunday);
  }

  Week substract(int weeks) {
    final newSunday = _sunday.substract(DateTime.daysPerWeek * weeks);
    return Week._internal(newSunday);
  }

  static List<Week> range(Week earliest, Week latest) {
    List<Week> allWeeks = [];

    var tempWeek = earliest;
    do {
      allWeeks.add(tempWeek);

      tempWeek = tempWeek.add(1);
    } while (tempWeek.isBefore(latest));

    allWeeks.add(latest);

    return allWeeks;
  }

  @override
  bool operator ==(Object other) {
    return other is Week && isSame(other);
  }

  @override
  int get hashCode => _sunday.hashCode;
}
