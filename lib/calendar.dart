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
  DateTime start;
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

  setTime(DateTime start, DateTime end) {
    isAllDay = false;

    this.start = start.toUtc();
    this.end = end.toUtc();
  }

  setTimeAsAllDay(DateTime start, DateTime end) {
    isAllDay = true;

    final startTime = start.toLocal();
    final startDate = Date.fromTime(startTime);

    this.start = startDate.utcTime();

    final endTime = end.toLocal();
    final endDate = Date.fromTime(endTime);

    this.end = endDate.utcTime();
  }

  setEnd(DateTime time) {
    end = time.toUtc();
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
