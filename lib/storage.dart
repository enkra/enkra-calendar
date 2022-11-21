import 'dart:convert';

import 'package:ical/src/event.dart';

import 'calendar.dart';
import 'native.dart';
import 'date.dart';

class IEventsInDb extends IEvents {
  @override
  Future<List<IEvent>> fetchEvent(Date start, Date end) async {
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
    final ops = """
     mutation {
       deleteEvent(uid: "$uid")
     }
     """;

    await CalendarNative.queryCalendarDb(ops);
  }
}

class InboxNotesInDb extends InboxNotes {
  @override
  Future<List<InboxNote>> fetch() async {
    final ops = """
     query {
       fetchInboxNote {
           id
           time
           content
        }
     }
     """;

    List<dynamic> notes =
        (await CalendarNative.queryCalendarDb(ops))['fetchInboxNote']!;

    return notes
        .map((n) => InboxNote.build(
              id: n["id"],
              content: n["content"],
              time: DateTime.parse(n["time"]),
            ))
        .toList();
  }

  @override
  Future<void> add(InboxNote note) async {
    final ops = """
     mutation {
       addInboxNote(
         note: {
           id: "${note.id}",
           time: "${note.time.toUtc().toIso8601String()}",
           content: "${note.content}",
         }
       ) {
           id
        }
     }
     """;

    await CalendarNative.queryCalendarDb(ops);
  }

  @override
  Future<void> remove(String id) async {
    final ops = """
     mutation {
       deleteInboxNote(id: "$id")
     }
     """;

    await CalendarNative.queryCalendarDb(ops);
  }
}
