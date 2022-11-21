import 'dart:convert';

import 'package:ical/src/event.dart';

import 'calendar.dart';
import 'native.dart';
import 'date.dart';

class IEventsInDb extends IEvents {
  @override
  Future<List<CalendarEvent>> fetchEvent(Date start, Date end) async {
    final startTime = start.localTime().toUtc();
    final endTime = end.localEndOfDay().toUtc();

    final ops = """
     query {
       fetchEvent(start: "${startTime}", end: "${endTime}") {
           uid
           start
           end
           summary
           description
           isAllDay
        }
     }
     """;

    List<dynamic> events =
        (await CalendarNative.queryCalendarDb(ops, null))['fetchEvent']!;

    return events
        .map((e) => CalendarEvent(
              uid: e["uid"],
              start: DateTime.parse(e["start"]),
              end: DateTime.parse(e["end"]),
              summary: e["summary"],
              description: e["description"],
              isAllDay: e["isAllDay"] as bool,
            ))
        .toList();
  }

  @override
  Future<void> add(CalendarEvent event) async {
    final ops = """
     mutation AddEvent(\$summary: String!, \$description: String, \$isAllDay: Boolean!){
       addEvent(
         event: {
           uid: "${event.uid}",
           summary: \$summary,
           start: "${event.start.toUtc().toIso8601String()}",
           end: "${event.end!.toUtc().toIso8601String()}",
           description: \$description,
           isAllDay: \$isAllDay,
         }
       ) {
           uid
           start
           summary
        }
     }
     """;

    final vars = jsonEncode({
      "summary": event.summary,
      "description": event.description,
      "isAllDay": event.isAllDay,
    });

    await CalendarNative.queryCalendarDb(ops, vars);
  }

  @override
  Future<void> remove(uid) async {
    final ops = """
     mutation {
       deleteEvent(uid: "$uid")
     }
     """;

    await CalendarNative.queryCalendarDb(ops, null);
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
        (await CalendarNative.queryCalendarDb(ops, null))['fetchInboxNote']!;

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
     mutation AddInboxNote(\$content: String!){
       addInboxNote(
         note: {
           id: "${note.id}",
           time: "${note.time.toUtc().toIso8601String()}",
           content: \$content,
         }
       ) {
           id
        }
     }
     """;

    final vars = jsonEncode({"content": note.content});

    await CalendarNative.queryCalendarDb(ops, vars);
  }

  @override
  Future<void> remove(String id) async {
    final ops = """
     mutation {
       deleteInboxNote(id: "$id")
     }
     """;

    await CalendarNative.queryCalendarDb(ops, null);
  }
}
