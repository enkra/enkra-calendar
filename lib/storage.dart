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

    final ops = """
     query {
       fetchEvent(start: "${startTime}", end: "${endTime}") {
           uid
           start
           summary
        }
     }
     """;

    List<dynamic> events =
        (await CalendarNative.queryCalendarDb(ops))['fetchEvent']!;

    return events
        .map((e) => IEvent(
              uid: e["uid"],
              status: IEventStatus.CONFIRMED,
              start: DateTime.parse(e["start"]),
              summary: e["summary"],
            ))
        .toList();
  }

  @override
  Future<void> add(IEvent event) async {
    await _setup;

    final ops = """
     mutation {
       addEvent(
         event: {
           uid: "${event.uid}",
           summary: "${event.summary}",
           start: "${event.start.toUtc().toIso8601String()}",
         }
       ) {
           uid
           start
           summary
        }
     }
     """;

    await CalendarNative.queryCalendarDb(ops);
  }

  @override
  Future<void> remove(uid) async {
    await _setup;

    final ops = """
     mutation {
       deleteEvent(uid: "$uid")
     }
     """;

    await CalendarNative.queryCalendarDb(ops);
  }
}
