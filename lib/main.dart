import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:provider/provider.dart';

import 'pages/calendar.dart';
import 'pages/inbox.dart';
import 'pages/tab_page.dart';
import 'calendar.dart';
import 'storage.dart';
import 'theme.dart';

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
    return MaterialApp(
      title: 'Enkra Calandar',
      theme: ThemeData.from(
        colorScheme: const ColorScheme.light().copyWith(
          primary: theme.primary,
          secondary: theme.secondary,
          onPrimary: theme.onPrimary,
          surface: theme.background,
          background: theme.background,
          error: theme.danger,
          tertiary: theme.miscColor,
        ),
      ).copyWith(
        scaffoldBackgroundColor: theme.background,
        appBarTheme: AppBarTheme(
          color: theme.background,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: theme.background,
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
    final calendarPageDay = useState(today);

    switch (pageIndex.value) {
      case PageIndex.calendar:
        return buildCalendarPage(
          context,
          pageIndex: pageIndex,
          calendarSelectedDay: calendarSelectedDay,
          calendarPageDay: calendarPageDay,
        );

      case PageIndex.inbox:
        return buildInboxPage(context, pageIndex: pageIndex);
    }
  }
}
