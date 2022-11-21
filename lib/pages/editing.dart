import 'package:calendar_mvp/data.dart';
import 'package:flutter/material.dart';
import 'package:ical/src/event.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../date.dart';

part 'editing.g.dart';

@hwidget
Widget editingPage(
  BuildContext context, {
  required Date initialDay,
}) {
  final summary = useRef("");

  final now = DateTime.now();

  final initialStart =
      DateTime(initialDay.year, initialDay.month, initialDay.day, now.hour + 1);
  final initialEnd = initialStart.add(const Duration(hours: 1));

  final start = useRef<DateTime>(initialStart);

  final description = useRef<String?>("");

  var focusNode = FocusNode();

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

                calendarManager.addEvent(
                  IEvent(
                    status: IEventStatus.CONFIRMED,
                    start: start.value,
                    summary: summary.value,
                    description: description.value,
                  ),
                );

                Navigator.pop(context);
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
            focusNode: focusNode,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (val) => summary.value = val,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(
            Icons.timer,
          ),
          title: const Text("All day"),
          trailing: Switch(
            value: false,
            onChanged: (_) {},
          ),
        ),
        ListTile(
          leading: const SizedBox(),
          title: _TimePicker(
            initialTime: initialStart,
            onTimePicked: (time) {
              start.value = time;
            },
          ),
        ),
        ListTile(
          leading: const SizedBox(),
          title: _TimePicker(
            initialTime: initialEnd,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(
            Icons.content_copy,
          ),
          title: TextField(
            decoration: const InputDecoration(
              hintText: "Add description",
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: Colors.black,
              ),
            ),
            onChanged: (val) => description.value = val,
          ),
        ),
      ],
    ),
    resizeToAvoidBottomInset: false,
  );
}

@hwidget
Widget _timePicker(
  BuildContext context, {
  required DateTime initialTime,
  void Function(DateTime)? onTimePicked,
}) {
  final time = useState(initialTime);

  final timeOfDay = TimeOfDay.fromDateTime(time.value);

  final dateString = DateFormat("E, MMM d, y").format(time.value);

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      InkWell(
        child: Text(dateString),
        onTap: () async {
          final date = await showDatePicker(
              context: context,
              initialDate: time.value,
              firstDate: DateTime(2015, 8),
              lastDate: DateTime(2101));

          if (date == null) {
            return;
          }

          time.value = DateTime(
            date.year,
            date.month,
            date.day,
            time.value.hour,
            time.value.minute,
          );

          onTimePicked?.call(time.value);
        },
      ),
      InkWell(
        child: Text(timeOfDay.format(context)),
        onTap: () async {
          final _time = await showTimePicker(
            initialTime: timeOfDay,
            context: context,
          );

          if (_time == null) {
            return;
          }

          time.value = DateTime(
            time.value.year,
            time.value.month,
            time.value.day,
            _time.hour,
            _time.minute,
          );

          onTimePicked?.call(time.value);
        },
      ),
    ],
  );
}
