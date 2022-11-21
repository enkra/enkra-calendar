import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:ical/src/event.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data.dart';
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

  final selectedDay = useState<Date?>(today);

  final scrolledToDay = useState(today);

  return Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(
          vertical: 16.0,
        ),
        child: _CalendarPanel(
            focusedDay: scrolledToDay.value,
            onDaySelected: (day) {
              final date = Date.fromTime(day);

              selectedDay.value = date;
              scrolledToDay.value = date;

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
        onDateScroll: (date) {
          scrolledToDay.value = date;
          selectedDay.value = null;

          onDateChanged(date);
        },
      ))
    ],
  );
}

@hwidget
Widget _calendarPanel(
  BuildContext context, {
  required Date focusedDay,
  void Function(DateTime day)? onDaySelected,
}) {
  final firstDay = focusedDay.substract(90);
  final lastDay = focusedDay.add(90);

  final theme = Theme.of(context);

  final calendarFormat = useState(CalendarFormat.month);

  return Consumer<CalendarManager>(builder: (context, calendarManager, child) {
    return TableCalendar<IEvent>(
      firstDay: firstDay.utcTime(),
      lastDay: lastDay.utcTime(),
      focusedDay: focusedDay.utcTime(),
      availableCalendarFormats: const {
        CalendarFormat.month: 'Month',
        CalendarFormat.week: 'Week',
      },
      selectedDayPredicate: (day) => isSameDay(focusedDay.utcTime(), day),
      calendarFormat: calendarFormat.value,
      eventLoader: (day) {
        return calendarManager.getByDate(Date.fromTime(day)).events;
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )))
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
        if (!isSameDay(focusedDay.utcTime(), _selectedDay)) {
          onDaySelected?.call(_selectedDay);
        }
      },
      onFormatChanged: (format) {
        if (calendarFormat.value != format) {
          calendarFormat.value = format;
        }
      },
      onPageChanged: (_focusedDay) {},
    );
  });
}

class _DatePanelList extends HookWidget {
  _DatePanelList({
    Key? key,
    this.initialDay,
    this.onDateScroll,
  }) : super(key: key);

  final Date? initialDay;

  void Function(Date)? onDateScroll;

  int? _initialIndex;
  List<Date> _dates = [];

  _buildDates(CalendarManager calendarManager) {
    var dates = calendarManager.eventDays();

    dates.insert(0, calendarManager.today());

    if (initialDay != null) {
      dates.insert(0, initialDay!);
    }

    dates = dates.toSet().toList();

    dates.sort();

    final eventWeeks = dates.map((day) => Week.fromDate(day)).toList();

    final earliestWeek = eventWeeks.first.substract(15);
    final latestWeek = eventWeeks.last.add(15);

    var allWeeks = Week.range(earliestWeek, latestWeek);

    for (var w in eventWeeks) {
      allWeeks.remove(w);
    }

    final allWeekFirstDays = allWeeks.map((week) => week.firstDay());

    List<Date> allDays = [...dates, ...allWeekFirstDays];

    allDays.sort();

    _dates = allDays;

    if (initialDay != null) {
      _initialIndex = _dates.indexOf(initialDay!);
    }
  }

  _listenPositionChanges(
      ValueListenable<Iterable<ItemPosition>> itemPosistions) {
    itemPosistions.addListener(() {
      final index = itemPosistions.value.firstOrNull?.index;

      if (index == null) {
        return;
      }

      final date = _dates[index];

      if (initialDay == null) {
        return onDateScroll?.call(date);
      }

      if (!date.isSame(initialDay!)) {
        return onDateScroll?.call(date);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemScrollController = useState(ItemScrollController());

    return Consumer<CalendarManager>(
      builder: (context, calendarManager, child) {
        _buildDates(calendarManager);

        final itemPositionsListener = ItemPositionsListener.create();
        final position = itemPositionsListener.itemPositions;

        _listenPositionChanges(position);

        final dateCount = _dates.length;

        if (itemScrollController.value.isAttached && _initialIndex != null) {
          itemScrollController.value.jumpTo(index: _initialIndex!);
        }

        return ScrollablePositionedList.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
          ),
          itemCount: dateCount,
          separatorBuilder: (context, _) => const Divider(
            height: 1,
          ),
          itemBuilder: (context, index) {
            final date = _dates[index];
            final events = calendarManager.getByDate(date);

            final isToday = calendarManager.isToday(date);

            if (events.events.isNotEmpty || isToday || date == initialDay) {
              return _EventDatePanel(date, events);
            } else {
              return _FreeWeekPanel(
                week: Week.fromDate(date),
              );
            }
          },
          initialScrollIndex: _initialIndex ?? 0,
          itemScrollController: itemScrollController.value,
          itemPositionsListener: itemPositionsListener,
        );
      },
    );
  }
}

@swidget
Widget _eventDatePanel(BuildContext context, Date date, DateEvent event) {
  final calendarManager = Provider.of<CalendarManager>(context, listen: false);

  final isToday = calendarManager.isToday(date);

  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;

      final columnWidth = (width - 3 * 16) / 4;

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: columnWidth,
              child: _DateIndicator(
                date: date,
                highlight: isToday,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _EventList(event),
            )
          ],
        ),
      );
    },
  );
}

@swidget
Widget _freeWeekPanel(
  BuildContext context, {
  required Week week,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;

      final singleColumnWidth = (width - 3 * 16) / 4;

      final columnWidth = singleColumnWidth;

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: SizedBox(
                width: columnWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _DateMonthIndicator(date: week.firstDay()),
                    Container(
                      color: Colors.black,
                      width: 10,
                      height: 1,
                    ),
                    _DateMonthIndicator(date: week.lastDay()),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
                child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Nothing planned",
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            )),
          ],
        ),
      );
    },
  );
}

@swidget
Widget _dateIndicator(
  BuildContext context, {
  required Date date,
  bool highlight = false,
}) {
  final theme = Theme.of(context);

  final color = highlight ? theme.colorScheme.primary : Colors.black;

  return SizedBox(
      child: Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        date.format(DateFormat(DateFormat.ABBR_WEEKDAY)),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 15,
        ),
      ),
      Text(
        date.day.toString(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 24,
        ),
      ),
    ],
  ));
}

@swidget
Widget _eventList(BuildContext context, DateEvent event) {
  final holiday = event.holidays.firstOrNull;

  if (event.events.isEmpty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        EventContainer(
          child: Text(
            "Noting planned",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  } else {
    final eventBoxes = event.events.map((e) => _EventBox(e));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DateInfo(
          holiday: holiday,
          birthdays: event.birthdays,
          anniversaries: event.anniversaries,
        ),
        ...eventBoxes
      ],
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
  final time = TimeOfDay.fromDateTime(event.start).format(context);

  return EventContainer(
    child: Column(
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
