import 'package:flutter/material.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:animations/animations.dart';

import 'drawer.dart';

part 'tab_page.g.dart';

const bottomMenus = [
  BottomNavigationBarItem(icon: Icon(Icons.today), label: "Calendar"),
  BottomNavigationBarItem(icon: Icon(Icons.list), label: "Inbox"),
];

enum PageIndex {
  calendar,
  inbox,
}

@swidget
Widget tabPage(
  BuildContext context, {
  required int tabIndex,
  required Widget body,
  AppBar? appBar,
  FloatingActionButton? floatingActionButton,
  void Function(int)? onIndexChanged,
}) {
  return Scaffold(
    appBar: appBar,
    body: PageTransitionSwitcher(
      transitionBuilder: (
        Widget child,
        Animation<double> primaryAnimation,
        Animation<double> secondaryAnimation,
      ) {
        return SharedAxisTransition(
            transitionType: SharedAxisTransitionType.horizontal,
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            child: child);
      },
      child: body,
    ),
    floatingActionButton: floatingActionButton,
    bottomNavigationBar: BottomNavigationBar(
      items: bottomMenus,
      onTap: (index) {
        onIndexChanged?.call(index);
      },
      currentIndex: tabIndex,
    ),
    drawer: const NavDrawer(),
  );
}
