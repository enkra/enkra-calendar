import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:ical/src/event.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../calendar.dart';
import '../date.dart';
import 'common.dart';
import 'tab_page.dart';
import 'editing.dart';

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
Widget _calendarPanel(
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

  return TableCalendar<IEvent>(
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
    calendarStyle: CalendarStyle(
      outsideDaysVisible: true,
      defaultTextStyle: const TextStyle(fontWeight: FontWeight.bold),
      weekendTextStyle:
          const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
      outsideTextStyle:
          const TextStyle(fontWeight: FontWeight.bold, color: Colors.black26),
      holidayTextStyle: const TextStyle(fontWeight: FontWeight.bold),
      selectedDecoration: BoxDecoration(
        color: theme.primaryColor,
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
          color: theme.primaryColor,
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange,
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
    onDaySelected: (DateTime _selectedDay, DateTime _focusedDay) {
      if (!isSameDay(focusedDay.value, _selectedDay)) {
        onDaySelected?.call(_selectedDay);
      }
      selectedDay.value = _selectedDay;
      focusedDay.value = _focusedDay;
    },
    onFormatChanged: (format) {
      if (calendarFormat.value != format) {
        calendarFormat.value = format;
      }
    },
    onPageChanged: (_focusedDay) {
      focusedDay.value = _focusedDay;

      onDaySelected?.call(_focusedDay);
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
Widget _eventList(
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
Widget _dateInfo(
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
Widget _eventBox(BuildContext context, IEvent event) {
  final time = TimeOfDay.fromDateTime(event.start.toLocal()).format(context);

  return Material(
    type: MaterialType.card,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                color: Colors.orange,
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
                Text(time,
                    style: const TextStyle(
                      color: Color(0xff808691),
                      fontWeight: FontWeight.w400,
                    )),
              ],
            ),
          ],
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => EditingPage(
                    initialDay: Date.fromTime(DateTime.now()),
                    eventToEdit: event,
                  )),
        );
      },
      onLongPress: () {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              final calendarManager =
                  Provider.of<CalendarManager>(context, listen: false);

              final leadDialog = SimpleDialog(
                children: <Widget>[
                  SimpleDialogOption(
                    onPressed: () {
                      if (event.uid != null) {
                        calendarManager.removeEvent(event.uid!);
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Delete'),
                  ),
                ],
              );
              return leadDialog;
            });
      },
    ),
  );
}

@swidget
Widget _dateMonthIndicator(BuildContext context, {required Date date}) {
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
