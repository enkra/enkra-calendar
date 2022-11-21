import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../date.dart';
import '../calendar.dart';

part 'editing.g.dart';

@hwidget
Widget editingPage(
  BuildContext context, {
  required Date initialDay,
  CalendarEvent? eventToEdit,
}) {
  final event = useState(eventToEdit?.copy() ??
      CalendarEvent(
        start: DateTime.utc(initialDay.year, initialDay.month, initialDay.day),
        end: DateTime.utc(initialDay.year, initialDay.month, initialDay.day),
        isAllDay: true,
      ));

  final timeRanger = useState(EventTimeRanger(
    start: event.value.localStart(),
    end: event.value.localEnd(),
    isAllDay: event.value.isAllDay,
  ));

  final theme = Theme.of(context);

  return Scaffold(
    appBar: AppBar(
      leading: const CloseButton(),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: ElevatedButton(
              onPressed: () {
                final calendarManager =
                    Provider.of<CalendarManager>(context, listen: false);

                final time = timeRanger.value;
                if (time.isAllDay) {
                  event.value.setTimeAsAllDay(time.start, time.end);
                } else {
                  event.value.setTime(time.start, time.end);
                }

                if (event.value.uid == null) {
                  calendarManager.createEvent(
                    event.value,
                  );
                } else {
                  calendarManager.updateEvent(
                    event.value,
                  );
                }

                Navigator.pop(context, true);
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        )
      ],
    ),
    body: Column(
      children: [
        ListTile(
          leading: const SizedBox(),
          title: TextField(
            controller: TextEditingController(
              text: event.value.summary,
            ),
            decoration: const InputDecoration(
              hintText: "Add title",
              border: InputBorder.none,
              hintStyle: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            focusNode: FocusNode(),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (val) {
              event.value.summary = val;
            },
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(
            Icons.timer,
          ),
          title: const Text("All day"),
          trailing: Switch(
            activeColor: theme.primaryColor,
            value: timeRanger.value.isAllDay,
            onChanged: (isAllDay) {
              timeRanger.value.isAllDay = isAllDay;
              timeRanger.notifyListeners();
            },
          ),
        ),
        ListTile(
          leading: const SizedBox(),
          title: _TimePicker(
            initialTime: timeRanger.value.localStart(),
            isShowTime: !timeRanger.value.isAllDay,
            onTimePicked: (time) {
              timeRanger.value.setStart(time);
              timeRanger.notifyListeners();
            },
          ),
        ),
        ListTile(
          leading: const SizedBox(),
          title: _TimePicker(
            initialTime:
                timeRanger.value.localEnd() ?? timeRanger.value.localStart(),
            isShowTime: !timeRanger.value.isAllDay,
            onTimePicked: (time) {
              timeRanger.value.setEnd(time);
              timeRanger.notifyListeners();
            },
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(
            Icons.content_copy,
          ),
          title: Shortcuts(
            shortcuts: <LogicalKeySet, Intent>{
              LogicalKeySet(LogicalKeyboardKey.enter):
                  DoNothingAndStopPropagationIntent(),
            },
            child: TextField(
              controller: TextEditingController(
                text: event.value.description,
              ),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 10,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "Add description",
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Colors.black,
                ),
              ),
              onChanged: (val) {
                event.value.description = val;
              },
            ),
          ),
        ),
      ],
    ),
    resizeToAvoidBottomInset: false,
  );
}

@hwidget
Widget __timePicker(
  BuildContext context, {
  required DateTime initialTime,
  void Function(DateTime)? onTimePicked,
  bool isShowTime = true,
}) {
  final time = initialTime;

  final timeOfDay = TimeOfDay.fromDateTime(time);

  final dateString = DateFormat("E, MMM d, y").format(time);

  var widgets = [
    InkWell(
      child: Text(dateString),
      onTap: () async {
        final date = await showDatePicker(
            context: context,
            initialDate: time,
            firstDate: DateTime(2015, 8),
            lastDate: DateTime(2101));

        if (date == null) {
          return;
        }

        final newTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        onTimePicked?.call(newTime);
      },
    ),
  ];

  if (isShowTime) {
    widgets.add(
      InkWell(
        child: Text(timeOfDay.format(context)),
        onTap: () async {
          final newTime = await showTimePicker(
            initialTime: timeOfDay,
            context: context,
          );

          if (newTime == null) {
            return;
          }

          final result = DateTime(
            time.year,
            time.month,
            time.day,
            newTime.hour,
            newTime.minute,
          );

          onTimePicked?.call(result);
        },
      ),
    );
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: widgets,
  );
}
