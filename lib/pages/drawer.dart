import 'package:flutter/material.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'drawer.g.dart';

@hwidget
Widget checkboxItem(
  BuildContext context, {
  required String title,
  Color? color,
}) {
  final isChecked = useState(true);

  return Material(
    color: Colors.grey[100],
    child: ListTile(
      title: Text(title),
      leading: SizedBox.square(
        dimension: 40,
        child: Checkbox(
            fillColor: MaterialStateProperty.all(color),
            value: isChecked.value,
            onChanged: (_) {
              isChecked.value = !isChecked.value;
            }),
      ),
      onTap: () {
        isChecked.value = !isChecked.value;
      },
    ),
  );
}

@swidget
Widget navDrawer(BuildContext context) {
  final theme = Theme.of(context);

  final statusBarHeight = MediaQuery.of(context).padding.top;

  final drawerHeader = Container(
    height: statusBarHeight + 30,
    margin: const EdgeInsets.only(bottom: 8.0),
    child: AnimatedContainer(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: const Icon(Icons.calendar_month_outlined),
          ),
          const SizedBox(width: 10),
          Text("Abraca Calender",
              style: TextStyle(
                fontSize: 24,
                color: theme.colorScheme.primary,
              )),
        ],
      ),
    ),
  );

  final drawerItems = Container(
    color: Colors.grey[100],
    child: ListView(
      children: [
        drawerHeader,
        const ListTile(
          title: Text(
            "About",
          ),
          leading: SizedBox.square(
            dimension: 40,
            child: Icon(
              Icons.help_rounded,
              color: Colors.grey,
            ),
          ),
        ),
        const ListTile(
          title: Text(
            "Licenses",
          ),
          leading: SizedBox.square(
            dimension: 40,
            child: Icon(
              Icons.source_rounded,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    ),
  );
  return Drawer(child: drawerItems);
}
