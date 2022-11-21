import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:ical/src/event.dart';
import 'package:nanoid/nanoid.dart';

import 'date.dart';

class DateEvent {
  final List<IEvent> events;

  final List<String> holidays;
  final List<String> birthdays;
  final List<String> anniversaries;

  const DateEvent({
    this.events = const [],
    this.holidays = const [],
    this.birthdays = const [],
    this.anniversaries = const [],
  });
}

abstract class IEvents {
  Future<List<IEvent>> getAll();

  Future<void> add(IEvent event);

  Future<void> remove(String uid);
}

class CalendarManager extends ChangeNotifier {
  final IEvents _events;

  final List<IEvent> _cached_events = <IEvent>[];

  CalendarManager(IEvents events)
      : _events = events,
        super() {
    _loadData();
  }

  _loadData() async {
    _cached_events.addAll(await _events.getAll());

    notifyListeners();
  }

  createEvent(IEvent event) {
    event.uid = nanoid(32);

    _events.add(event);
    _cached_events.add(event);

    notifyListeners();
  }

  updateEvent(IEvent event) {
    for (var d in _cached_events.asMap().entries) {
      if (d.value.uid == event.uid) {
        _cached_events[d.key] = event;
      }
    }

    _events.add(event);

    notifyListeners();
  }

  removeEvent(String uid) {
    _events.remove(uid);
    _cached_events.removeWhere((e) => e.uid == uid);

    notifyListeners();
  }

  DateEvent getByDate(Date date) {
    final events =
        _cached_events.where((event) => date.isSameDay(event.start)).toList();

    return DateEvent(events: events);
  }

  List<Date> eventDays() {
    final days = _cached_events
        .map((event) => event.start)
        .map((time) => Date.fromTime(time))
        .toSet()
        .toList();

    return days;
  }

  bool isToday(Date date) {
    return date.isSame(today());
  }

  Date today() {
    final time = DateTime.now();

    return Date.fromTime(time);
  }
}
