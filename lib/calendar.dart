import 'dart:async';

import "package:collection/collection.dart";
import 'package:flutter/foundation.dart';

import 'package:ical/src/event.dart';
import 'package:ical/src/abstract.dart';
import 'package:ical/src/subcomponents.dart';
import 'package:nanoid/nanoid.dart';

import 'date.dart';

class DateEvent {
  final List<CalendarEvent> events;

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
  Future<List<CalendarEvent>> fetchEvent(Date start, Date end);

  Future<void> add(CalendarEvent event);

  Future<void> remove(String uid);
}

class InboxNote {
  String id;

  DateTime time;
  String content;

  InboxNote({
    required this.content,
  })  : id = nanoid(),
        time = DateTime.now();

  InboxNote.build({
    required this.id,
    required this.time,
    required this.content,
  });
}

abstract class InboxNotes {
  Future<List<InboxNote>> fetch();

  Future<void> add(InboxNote note);

  Future<void> remove(String id);
}

class CalendarManager extends ChangeNotifier {
  final IEvents _events;

  final InboxNotes _inboxNotes;

  CalendarManager(IEvents events, InboxNotes inboxNotes)
      : _events = events,
        _inboxNotes = inboxNotes,
        super();

  createEvent(CalendarEvent event) {
    event.uid = nanoid(32);

    _events.add(event);

    notifyListeners();
  }

  updateEvent(CalendarEvent event) {
    _events.add(event);

    notifyListeners();
  }

  removeEvent(String uid) {
    _events.remove(uid);

    notifyListeners();
  }

  Future<Map<Date, DateEvent>> getByDateRange(Date start, Date end) async {
    final events =
        (await _events.fetchEvent(start, end)).map((CalendarEvent e) {
      e.start = e.start.toLocal();
      return e;
    }).toList();

    final eventMap =
        groupBy(events, (CalendarEvent e) => Date.fromTime(e.start))
            .map((day, events) {
      final sortedEvents = events.sortedBy((e) => e.start).toList();
      return MapEntry(day, DateEvent(events: sortedEvents));
    });

    return eventMap;
  }

  bool isToday(Date date) {
    return date.isSame(today());
  }

  Date today() {
    final time = DateTime.now();

    return Date.fromTime(time);
  }

  Future<List<InboxNote>> inboxNotes() async {
    return (await _inboxNotes.fetch())
        .map((n) {
          n.time = n.time.toLocal();
          return n;
        })
        .sortedBy((n) => n.time)
        .toList();
  }

  addNote(InboxNote note) {
    _inboxNotes.add(note);

    notifyListeners();
  }

  deleteNote(String noteId) {
    _inboxNotes.remove(noteId);

    notifyListeners();
  }

  createEventFromIndexNote(InboxNote note) {
    final today = Date.fromTime(DateTime.now()).utcTime();

    if (note.content.length <= 16) {
      return CalendarEvent(
        start: today,
        end: today,
        summary: note.content,
        isAllDay: true,
      );
    } else {
      return CalendarEvent(
        start: today,
        end: today,
        summary: note.content.substring(0, 16),
        description: note.content,
        isAllDay: true,
      );
    }
  }
}

class CalendarEvent {
  String? uid;
  String? summary;
  String? description;
  // UTC time
  DateTime start;
  // UTC time
  DateTime? end;

  bool isAllDay;

  CalendarEvent({
    this.uid,
    this.summary,
    this.description,
    required this.start,
    this.end,
    this.isAllDay = false,
  });

  CalendarEvent copy() {
    return CalendarEvent(
      uid: uid,
      summary: summary,
      description: description,
      start: start,
      end: end,
      isAllDay: isAllDay,
    );
  }

  setTime(DateTime start, DateTime? end) {
    isAllDay = false;

    this.start = start.toUtc();
    this.end = end?.toUtc();
  }

  getDate(DateTime? time) {
    final localTime = time?.toLocal();

    if (localTime != null) {
      final date = Date.fromTime(localTime);
      return date.utcTime();
    }

    return null;
  }

  setTimeAsAllDay(DateTime start, DateTime? end) {
    isAllDay = true;

    this.start = getDate(start);
    this.end = getDate(end);
  }

  DateTime localStart() {
    if (isAllDay) {
      return Date.fromTime(start).localTime();
    } else {
      return start.toLocal();
    }
  }

  DateTime? localEnd() {
    if (isAllDay && end != null) {
      return Date.fromTime(end!).localTime();
    } else if (isAllDay && end == null) {
      final startDate = Date.fromTime(start);
      final endDate = startDate.add(1);

      return endDate.localTime();
    } else {
      return end?.toLocal();
    }
  }
}

class EventTimeRanger {
  // Local DateTime
  DateTime start;
  // Local DateTime
  DateTime? end;
  bool isAllDay;

  EventTimeRanger({
    required this.start,
    required this.end,
    this.isAllDay = false,
  });

  setStart(DateTime start) {
    if (isAllDay) {
      setStartAllDay(start);
    } else {
      setStartNormal(start);
    }
  }

  setEnd(DateTime end) {
    if (isAllDay) {
      setEndAllDay(end);
    } else {
      setEndNormal(end);
    }
  }

  setAllDay(bool isAllDay) {
    this.isAllDay = isAllDay;
  }

  setStartNormal(DateTime start) {
    isAllDay = false;

    final newStart = start.toLocal();
    var newEnd = end;

    if (newEnd != null && newEnd.difference(newStart) < Duration.zero) {
      final oldDiff = end!.difference(this.start);

      newEnd = newStart.add(oldDiff);
    }

    this.start = newStart;
    end = newEnd;
  }

  setEndNormal(DateTime end) {
    isAllDay = false;

    var newStart = start;
    final newEnd = end.toLocal();

    if (newEnd.difference(newStart) < Duration.zero) {
      final oldDiff = this.end?.difference(start);

      newStart = newEnd.subtract(oldDiff ?? Duration.zero);
    }

    start = newStart;
    this.end = newEnd;
  }

  getDate(DateTime time) {
    final localTime = time.toLocal();
    final date = Date.fromTime(localTime);

    return date.localTime();
  }

  setStartAllDay(DateTime start) {
    isAllDay = true;

    this.start = getDate(start);

    if (end != null && end!.difference(this.start) < Duration.zero) {
      end = this.start;
    }
  }

  setEndAllDay(DateTime end) {
    isAllDay = true;

    final newEnd = getDate(end);

    this.end = newEnd;

    if (newEnd.difference(start) < Duration.zero) {
      start = newEnd;
    }
  }

  DateTime localStart() {
    if (isAllDay) {
      return Date.fromTime(start).localTime();
    } else {
      return start.toLocal();
    }
  }

  DateTime? localEnd() {
    if (isAllDay && end != null) {
      return Date.fromTime(end!).localTime();
    } else if (isAllDay && end == null) {
      final startDate = Date.fromTime(start);
      final endDate = startDate.add(1);

      return endDate.localTime();
    } else {
      return end?.toLocal();
    }
  }
}
