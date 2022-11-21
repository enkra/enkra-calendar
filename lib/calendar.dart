import 'dart:async';

import "package:collection/collection.dart";
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
  Future<List<IEvent>> fetchEvent(Date start, Date end);

  Future<void> add(IEvent event);

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

  createEvent(IEvent event) {
    event.uid = nanoid(32);

    _events.add(event);

    notifyListeners();
  }

  updateEvent(IEvent event) {
    _events.add(event);

    notifyListeners();
  }

  removeEvent(String uid) {
    _events.remove(uid);

    notifyListeners();
  }

  Future<Map<Date, DateEvent>> getByDateRange(Date start, Date end) async {
    final events = (await _events.fetchEvent(start, end)).map((IEvent e) {
      e.start = e.start.toLocal();
      return e;
    }).toList();

    final eventMap = groupBy(events, (IEvent e) => Date.fromTime(e.start))
        .map((day, events) => MapEntry(day, DateEvent(events: events)));

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
    return (await _inboxNotes.fetch()).map((n) {
      n.time = n.time.toLocal();
      return n;
    }).toList();
  }

  addNote(InboxNote note) {
    _inboxNotes.add(note);

    notifyListeners();
  }

  deleteNote(String noteId) {
    _inboxNotes.remove(noteId);

    notifyListeners();
  }
}
