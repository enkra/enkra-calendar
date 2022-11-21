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

class InboxNote {
  String id;

  DateTime time;
  String content;

  InboxNote({
    required this.content,
  })  : id = nanoid(),
        time = DateTime.now();
}

class CalendarManager extends ChangeNotifier {
  final IEvents _events;

  final List<IEvent> _cached_events = <IEvent>[];

  final List<InboxNote> _cached_notes = <InboxNote>[
    InboxNote(content: "Meeting with Josh"),
    InboxNote(content: "Clean room"),
    InboxNote(content: "Shopping"),
    InboxNote(content: "Do math homework"),
    InboxNote(
        content:
            "Lorem Ipsum is simply dummy text of the printing and typesetting industry."
            " Lorem Ipsum has been the industry's standard dummy text ever since the 1500s,"
            " when an unknown printer took a galley of type and scrambled it to make a type"
            " specimen book. It has survived not only five centuries, but also the leap into"
            " electronic typesetting, remaining essentially unchanged. It was popularised in"
            " the 1960s with the release of Letraset sheets containing Lorem Ipsum passages,"
            " and more recently with desktop publishing software like Aldus PageMaker"
            " including versions of Lorem Ipsum."),
  ];

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

  List<InboxNote> inboxNotes() {
    return _cached_notes;
  }

  addNote(InboxNote note) {
    _cached_notes.add(note);

    notifyListeners();
  }

  deleteNote(String noteId) {
    _cached_notes.removeWhere((n) => n.id == noteId);

    notifyListeners();
  }
}
