import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:provider/provider.dart';

import '../date.dart';
import '../calendar.dart';
import 'editing.dart';

part 'detail.g.dart';

Widget renderTimeRange(CalendarEvent event) {
  final dateFormat = DateFormat('EEEE, MMM dd');
  final dateTimeFormat = DateFormat('EEEE, MMM dd • HH:mm');
  final timeFormat = DateFormat('HH:mm');

  if (event.isOneDay()) {
    if (event.isAllDay) {
      final startTime = dateFormat.format(event.localStart());

      var timeStr = startTime;

      return Text(timeStr);
    } else {
      final startTime = dateTimeFormat.format(event.localStart());

      var timeStr = startTime;

      final end = event.localEnd();

      if (end != null) {
        final endTime = timeFormat.format(end);

        timeStr = "$timeStr - $endTime";
      }

      return Text(timeStr);
    }
  } else {
    if (event.isAllDay) {
      final startTime = dateFormat.format(event.localStart());

      final endTime = dateFormat.format(event.localEnd()!);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$startTime —"),
          Text(endTime),
        ],
      );
    } else {
      final startTime = dateTimeFormat.format(event.localStart());

      final endTime = dateTimeFormat.format(event.localEnd()!);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$startTime —"),
          Text(endTime),
        ],
      );
    }
  }
}

@swidget
Widget eventDetailPage(
  BuildContext context, {
  required CalendarEvent event,
}) {
  return Consumer<CalendarManager>(builder: (context, calendarManager, child) {
    return FutureBuilder(
        future: calendarManager.getEvent(event.uid!),
        builder: (context, AsyncSnapshot<CalendarEvent?> e) {
          if (!e.hasData) {
            return Container();
          }
          CalendarEvent event = e.data!;

          Widget description = const Text(
            "No description",
            style: TextStyle(color: Colors.grey),
          );

          if (event.description != null) {
            description = Text(event.description!);
          }

          final time = renderTimeRange(event);

          final theme = Theme.of(context);

          return Scaffold(
            appBar: AppBar(
              leading: const CloseButton(),
              actions: [
                IconButton(
                  onPressed: () {
                    if (event.uid != null) {
                      calendarManager.removeEvent(event.uid!);
                    }
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.delete_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                IconButton(
                  onPressed: () => {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => EditingPage(
                                initialDay: Date.fromTime(DateTime.now()),
                                eventToEdit: event,
                              )),
                    )
                  },
                  icon: Icon(
                    Icons.edit_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                ListTile(
                  leading: const SizedBox(),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.summary!,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      time,
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.content_copy,
                  ),
                  title: description,
                ),
              ],
            ),
          );
        });
  });
}
