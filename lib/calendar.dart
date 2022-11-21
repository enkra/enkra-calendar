import 'dart:async';

import "package:collection/collection.dart";
import 'package:flutter/foundation.dart';

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

  Future<CalendarEvent?> get(String uid);
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

  Future<CalendarEvent?> getEvent(String uid) {
    return _events.get(uid);
  }

  Future<Map<Date, DateEvent>> getByDateRange(Date start, Date end) async {
    final events =
        (await _events.fetchEvent(start, end)).map((CalendarEvent e) {
      e.start = e.start;
      return e;
    }).toList();

    final eventMap =
        groupBy(events, (CalendarEvent e) => e.start.toLocal().date())
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
    return Date.today();
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
    final today = this.today().startOfDay().toUtc();

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

  setTimeAsAllDay(DateTime start, DateTime? end) {
    assert(start.isLocal);
    if (end != null) {
      assert(end.isLocal);
    }
    isAllDay = true;

    this.start = start.toUtc();
    this.end = end?.toUtc();
  }

  DateTime localStart() {
    if (isAllDay) {
      final date = start.toLocal().date();
      return date.startOfDay();
    } else {
      return start.toLocal();
    }
  }

  DateTime? localEnd() {
    if (isAllDay && end != null) {
      final date = end!.toLocal().date();

      return date.startOfDay();
    } else if (isAllDay && end == null) {
      final startDate = start.toLocal().date();

      return startDate.startOfDay();
    } else {
      return end?.toLocal();
    }
  }

  bool isOneDay() {
    if (end == null) {
      return true;
    }

    if (end!.difference(start) < const Duration(days: 1)) {
      return true;
    } else {
      return false;
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
    assert(start.isLocal);

    if (isAllDay) {
      _setStartAllDay(start);
    } else {
      _setStartNormal(start);
    }
  }

  setEnd(DateTime end) {
    assert(end.isLocal);

    if (isAllDay) {
      _setEndAllDay(end);
    } else {
      _setEndNormal(end);
    }
  }

  setAllDay(bool isAllDay) {
    this.isAllDay = isAllDay;
  }

  _setStartNormal(DateTime start) {
    assert(start.isLocal);

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

  _setEndNormal(DateTime end) {
    assert(end.isLocal);

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

  _getDate(DateTime time) {
    assert(time.isLocal);

    return time.date().startOfDay();
  }

  _setStartAllDay(DateTime start) {
    isAllDay = true;

    assert(start.isLocal);
    this.start = start.date().startOfDay();

    this.start = _getDate(start);

    if (end != null && end!.difference(this.start) < Duration.zero) {
      end = this.start;
    }
  }

  _setEndAllDay(DateTime end) {
    isAllDay = true;

    assert(end.isLocal);
    final newEnd = end.date().endOfDay();

    this.end = newEnd;

    if (newEnd.difference(start) < Duration.zero) {
      start = newEnd;
    }
  }

  DateTime localStart() {
    if (isAllDay) {
      return start.date().startOfDay();
    } else {
      return start.toLocal();
    }
  }

  DateTime? localEnd() {
    if (isAllDay && end != null) {
      return end!.date().startOfDay();
    } else if (isAllDay && end == null) {
      final startDate = start.date();

      return startDate.startOfDay();
    } else {
      return end?.toLocal();
    }
  }
}
