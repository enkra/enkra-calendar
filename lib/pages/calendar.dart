import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:provider/provider.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../calendar.dart';
import '../date.dart';
import 'common.dart';
import 'tab_page.dart';
import 'editing.dart';
import 'detail.dart';
import 'util.dart';

part 'calendar.g.dart';

Widget buildCalendarPage(
  BuildContext context, {
  required ValueNotifier<PageIndex> pageIndex,
  required ValueNotifier<Date> calendarSelectedDay,
}) {
  final theme = Theme.of(context);

  return TabPage(
    tabIndex: pageIndex.value.index,
    body: Calendar(
      onDateChanged: (day) => calendarSelectedDay.value = day,
    ),
    appBar: AppBar(
      title: Text(calendarSelectedDay.value.format(DateFormat.MMMM())),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => EditingPage(
                    initialDay: calendarSelectedDay.value,
                  )),
        );
      },
      backgroundColor: theme.colorScheme.primary,
      child: const Icon(Icons.add, color: Colors.white),
    ),
    onIndexChanged: (index) {
      pageIndex.value = PageIndex.values[index];
    },
  );
}

@hwidget
Widget calendar(
  BuildContext context, {
  required void Function(Date) onDateChanged,
}) {
  final calendarManager = Provider.of<CalendarManager>(context, listen: false);

  final today = calendarManager.today();

  final selectedDay = useState<Date>(today);

  final eventStartDay = selectedDay.value.substract(65);
  final eventEndDay = selectedDay.value.add(65);

  return Consumer<CalendarManager>(builder: (context, calendarManager, child) {
    return FutureBuilder(
        future: calendarManager.getByDateRange(eventStartDay, eventEndDay),
        builder: (context, AsyncSnapshot<Map<Date, DateEvent>> f) {
          Map<Date, DateEvent> events = f.hasData ? f.data! : {};

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                ),
                child: _CalendarPanel(
                    initialDay: selectedDay.value,
                    events: events,
                    onDaySelected: (day) {
                      final date = Date.fromTime(day);

                      selectedDay.value = date;

                      onDateChanged(date);
                    }),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                ),
                child: const Divider(
                  height: 1,
                ),
              ),
              Expanded(
                  child: _DatePanelList(
                initialDay: selectedDay.value,
                event: events[selectedDay.value],
              ))
            ],
          );
        });
  });
}

@hwidget
Widget __calendarPanel(
  BuildContext context, {
  required Date initialDay,
  required Map<Date, DateEvent> events,
  void Function(DateTime day)? onDaySelected,
}) {
  final today = Date.fromTime(DateTime.now());

  final firstDay = today.substract(365 * 2);
  final lastDay = today.add(365 * 2);

  final theme = Theme.of(context);

  final calendarFormat = useState(CalendarFormat.month);

  final focusedDay = useRef(initialDay.utcTime());
  final selectedDay = useState(initialDay.utcTime());

  return TableCalendar<CalendarEvent>(
    firstDay: firstDay.utcTime(),
    lastDay: lastDay.utcTime(),
    focusedDay: focusedDay.value,
    availableCalendarFormats: const {
      CalendarFormat.month: 'Month',
      CalendarFormat.week: 'Week',
    },
    selectedDayPredicate: (day) => isSameDay(selectedDay.value, day),
    calendarFormat: calendarFormat.value,
    eventLoader: (day) {
      return events[Date.fromTime(day)]?.events ?? [];
    },
    startingDayOfWeek: StartingDayOfWeek.sunday,
    rowHeight: 45.0,
    calendarStyle: CalendarStyle(
      outsideDaysVisible: true,
      defaultTextStyle: const TextStyle(fontWeight: FontWeight.bold),
      weekendTextStyle:
          const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
      outsideTextStyle:
          const TextStyle(fontWeight: FontWeight.bold, color: Colors.black26),
      holidayTextStyle: const TextStyle(fontWeight: FontWeight.bold),
      selectedDecoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      ),
      selectedTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      todayTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black54,
      ),
      todayDecoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: theme.colorScheme.primary,
          width: 2,
        ),
        shape: BoxShape.circle,
      ),
    ),
    daysOfWeekStyle: const DaysOfWeekStyle(
      weekdayStyle:
          TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
      weekendStyle:
          TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
    ),
    calendarBuilders: CalendarBuilders(
      markerBuilder: (context, date, list) {
        if (list.isEmpty) return Container();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: list
              .map((event) => Padding(
                  padding: const EdgeInsets.all(1),
                  child: Container(
                    height: 4,
                    width: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.tertiary,
                    ),
                  )))
              .take(4)
              .toList(),
        );
      },
    ),
    headerVisible: false,
    headerStyle: HeaderStyle(
        titleCentered: true,
        titleTextFormatter: (date, locale) =>
            DateFormat.MMMM(locale).format(date)),
    onDaySelected: (DateTime newSelectedDay, DateTime newFocusedDay) {
      if (!isSameDay(focusedDay.value, newSelectedDay)) {
        onDaySelected?.call(newSelectedDay);
      }
      selectedDay.value = newSelectedDay;
      focusedDay.value = newFocusedDay;
    },
    onFormatChanged: (format) {
      if (calendarFormat.value != format) {
        calendarFormat.value = format;
      }
    },
    onPageChanged: (newFocusedDay) {
      focusedDay.value = newFocusedDay;
    },
  );
}

class _DatePanelList extends HookWidget {
  const _DatePanelList({
    Key? key,
    required this.initialDay,
    this.event,
  }) : super(key: key);

  final Date initialDay;
  final DateEvent? event;

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarManager>(
        builder: (context, calendarManager, child) {
      final date = initialDay;

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _EventList(
                date: date,
                event: event ?? const DateEvent(),
              ),
            )
          ],
        ),
      );
    });
  }
}

@swidget
Widget __eventList(
  BuildContext context, {
  required Date date,
  required DateEvent event,
}) {
  final theme = Theme.of(context);

  final holiday = event.holidays.firstOrNull;

  final dateString = date.format(DateFormat("EEEE, MMMM d, y"));

  if (event.events.isEmpty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            dateString,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.today,
                  color: Colors.grey,
                  size: 60.0,
                ),
                Text(
                  "Noting planned",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  } else {
    // Sort events for a more clear view
    event.events.sort((a, b) {
      if (a.isAllDay && b.isAllDay) {
        return a.summary!.compareTo(b.summary!);
      }
      if (a.isAllDay) {
        return -1;
      }
      if (b.isAllDay) {
        return 1;
      }

      return a.start.compareTo(b.start);
    });

    final eventBoxes = event.events.map((e) => _EventBox(e));

    final eventCount = event.events.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              dateString,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              avatar: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                child: Text('$eventCount'),
              ),
              label: const Text('Tasks'),
              backgroundColor: Colors.grey[200],
            ),
          ),
          const SizedBox(height: 16),
          _DateInfo(
            holiday: holiday,
            birthdays: event.birthdays,
            anniversaries: event.anniversaries,
          ),
          ...eventBoxes
        ],
      ),
    );
  }
}

@swidget
Widget __dateInfo(
  BuildContext context, {
  String? holiday,
  List<String>? birthdays,
  List<String>? anniversaries,
}) {
  final theme = Theme.of(context);

  Widget holidayWidget = Container();

  if (holiday != null) {
    holidayWidget = EventContainer(
      child: Text(
        holiday,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  final birthdayWidgets = (birthdays ?? []).map(
    (birthday) => EventContainer(
      child: Row(
        children: [
          const Icon(
            Icons.cake,
            color: Colors.green,
            size: 20.0,
          ),
          Container(width: 4),
          Text(birthday,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
              )),
        ],
      ),
    ),
  );

  final anniversaryWidgets = (anniversaries ?? []).map(
    (anniversary) => EventContainer(
      child: Row(
        children: [
          const Icon(
            Icons.favorite,
            color: Colors.red,
            size: 20.0,
          ),
          Container(width: 4),
          Text(anniversary,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
              )),
        ],
      ),
    ),
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      holidayWidget,
      ...birthdayWidgets,
      ...anniversaryWidgets,
    ],
  );
}

@swidget
Widget __eventBox(BuildContext context, CalendarEvent event) {
  final time = TimeOfDay.fromDateTime(event.localStart()).format(context);

  onLongPress() {
    showMaterialModalBottomSheet(
      expand: false,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemQuickMenu(event: event),
    );
  }

  final theme = Theme.of(context);

  return Material(
    type: MaterialType.card,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => EventDetailPage(
                    event: event,
                  )),
        );
      },
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
              width: 12,
              height: 12,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.summary ?? "Event",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 8),
                event.isAllDay
                    ? Container()
                    : Text(time,
                        style: const TextStyle(
                          color: Color(0xff808691),
                          fontWeight: FontWeight.w400,
                        )),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

@swidget
Widget __dateMonthIndicator(BuildContext context, {required Date date}) {
  return SizedBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          date.format(DateFormat(DateFormat.ABBR_MONTH)),
          style: const TextStyle(
            fontWeight: FontWeight.normal,
            color: Colors.black,
            fontSize: 10,
          ),
        ),
        Text(
          date.day.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.normal,
            color: Colors.black,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}

@swidget
Widget __itemQuickMenu(
  BuildContext context, {
  required CalendarEvent event,
}) {
  final theme = Theme.of(context);

  return Material(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 5),
            Container(
              width: 30,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.all(
                  Radius.circular(2),
                ),
              ),
            ),
            ListTile(
              title: Text(
                'Edit',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              leading: Icon(
                Icons.edit_outlined,
                color: theme.colorScheme.primary,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => EditingPage(
                              initialDay: Date.fromTime(DateTime.now()),
                              eventToEdit: event,
                            )));
              },
            ),
            ListTile(
              title: Text(
                'Copy',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              leading: Icon(
                Icons.content_copy_outlined,
                color: theme.colorScheme.primary,
              ),
              onTap: () {
                Navigator.pop(context);

                copyToClipboardAutoClear(event.summary);
              },
            ),
            ListTile(
              title: Text(
                'Delete',
                style: TextStyle(
                  color: theme.colorScheme.error,
                ),
              ),
              leading: Icon(
                Icons.delete_outlined,
                color: theme.colorScheme.error,
              ),
              onTap: () {
                Navigator.pop(context);

                showConfirmDialog(
                  context: context,
                  content: "Delete this event?",
                  onOk: (context) {
                    final calendarManager =
                        Provider.of<CalendarManager>(context, listen: false);

                    if (event.uid != null) {
                      calendarManager.removeEvent(event.uid!);
                    }
                  },
                );
              },
            )
          ],
        ),
      ));
}
