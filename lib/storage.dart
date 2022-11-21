import 'dart:io';
import 'dart:convert';

import 'package:ical/src/event.dart';
import 'package:nanoid/nanoid.dart';
import 'package:path_provider/path_provider.dart';

import 'calendar.dart';

class IEventsInMemory extends IEvents {
  @override
  Future<List<IEvent>> getAll() async {
    final today = DateTime.now();

    final yestoday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    return [
      IEvent(
        uid: nanoid(32),
        status: IEventStatus.CONFIRMED,
        start: yestoday,
        summary: 'Skype with Selina',
      ),
      IEvent(
        uid: nanoid(32),
        status: IEventStatus.CONFIRMED,
        start: yestoday,
        summary: 'Lunch with Client',
      ),
      IEvent(
        uid: nanoid(32),
        status: IEventStatus.CONFIRMED,
        start: today,
        summary: 'Fitness',
      ),
      IEvent(
        uid: nanoid(32),
        status: IEventStatus.CONFIRMED,
        start: today,
        summary: 'Dentist Appointment',
      ),
      IEvent(
        uid: nanoid(32),
        status: IEventStatus.CONFIRMED,
        start: today,
        summary: 'Lunch time',
      ),
      IEvent(
        uid: nanoid(32),
        status: IEventStatus.CONFIRMED,
        start: tomorrow,
        summary: 'Fitness',
      ),
      IEvent(
        uid: nanoid(32),
        status: IEventStatus.CONFIRMED,
        start: tomorrow,
        summary: 'Dentist Appointment',
      ),
      IEvent(
        uid: nanoid(32),
        status: IEventStatus.CONFIRMED,
        start: tomorrow,
        summary: 'Lunch time',
      ),
    ];
  }

  @override
  add(IEvent event) async {}

  @override
  remove(String uid) async {}
}

class IEventsInJsonFile extends IEvents {
  Future<String> get _localPath async {
    final directory = await getApplicationSupportDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;

    final file = File('$path/events.json');

    if (!await file.exists()) {
      await file.create();
    }
    return file;
  }

  @override
  Future<List<IEvent>> getAll() async {
    try {
      final file = await _localFile;

      // Read the file
      final contents = await file.readAsString();

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
      // If encountering an error, return 0
      return [];
    }
  }

  storeAll(List<IEvent> events) async {
    final file = await _localFile;

    final data = events
        .map((e) => {
              "uid": e.uid,
              "summary": e.summary,
              "start": e.start.toString(),
              "description": e.description,
            })
        .toList();

    // Write the file
    await file.writeAsString(jsonEncode(data));
  }

  @override
  Future<void> add(IEvent event) async {
    final events = await getAll();

    events.add(event);

    await storeAll(events);
  }

  @override
  Future<void> remove(uid) async {
    final events = await getAll();

    events.removeWhere((e) => e.uid == uid);

    await storeAll(events);
  }
}
