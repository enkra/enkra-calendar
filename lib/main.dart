import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:provider/provider.dart';

import 'pages/calendar.dart';
import 'pages/inbox.dart';
import 'pages/tab_page.dart';
import 'calendar.dart';
import 'storage.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  runApp(
    ChangeNotifierProvider(
      create: (context) {
        return CalendarManager(IEventsInDb(), InboxNotesInDb());
      },
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xff5046e5);

    return MaterialApp(
      title: 'Calandar Demo',
      theme: ThemeData.from(
        colorScheme: const ColorScheme.light().copyWith(
          primary: brandColor,
          onPrimary: Colors.white,
        ),
      ).copyWith(
        appBarTheme: const AppBarTheme(
          color: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends HookWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pageIndex = useState(PageIndex.calendar);

    final calendarManager =
        Provider.of<CalendarManager>(context, listen: false);

    final today = calendarManager.today();
    final calendarSelectedDay = useState(today);

    switch (pageIndex.value) {
      case PageIndex.calendar:
        return buildCalendarPage(
          context,
          pageIndex: pageIndex,
          calendarSelectedDay: calendarSelectedDay,
        );

      case PageIndex.inbox:
        return buildInboxPage(context, pageIndex: pageIndex);
    }
  }
}
