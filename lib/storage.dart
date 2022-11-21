import 'dart:convert';

import 'package:ical/src/event.dart';

import 'calendar.dart';
import 'native.dart';
import 'date.dart';

class IEventsInJsonFile extends IEvents {
  final Future<void> _setup;

  IEventsInJsonFile() : _setup = CalendarNative.setup();

  @override
  Future<List<IEvent>> fetchEvent(Date start, Date end) async {
    await _setup;

    final startTime = start.localTime().toUtc();
    final endTime = end.localEndOfDay().toUtc();

    try {
      final contents = await CalendarNative.fetchEvent(
        startTime.toIso8601String(),
        endTime.toIso8601String(),
      );

      List<dynamic> events = jsonDecode(contents);

      return events
          .map((e) => IEvent(
                uid: e["uid"],
                status: IEventStatus.CONFIRMED,
                start: DateTime.parse(e["start"]),
                summary: e["summary"],
              ))
          .toList();
    } catch (e) {
      // If encountering an error, return empty list
      return [];
    }
  }

  @override
  Future<void> add(IEvent event) async {
    await _setup;

    final e = {
      "uid": event.uid,
      "summary": event.summary,
      "start": event.start.toString(),
      "description": event.description,
    };

    await CalendarNative.addEvent(jsonEncode(e));
  }

  @override
  Future<void> remove(uid) async {
    await _setup;

    await CalendarNative.deleteEvent(uid);
  }
}
