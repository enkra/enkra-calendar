import 'package:flutter/material.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
      child: SafeArea(
          child: Padding(
        padding: const EdgeInsets.only(bottom: 45),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            drawerHeader,
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text(
                      "About",
                    ),
                    leading: const SizedBox.square(
                      dimension: 40,
                      child: Icon(
                        Icons.help_rounded,
                        color: Colors.grey,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const _AboutPage()),
                      );
                    },
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
            ),
            const _VersionTag(),
          ],
        ),
      )));
  return Drawer(child: drawerItems);
}

@swidget
Widget _versionTag(BuildContext context) {
  return FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, AsyncSnapshot<PackageInfo> s) {
        final packageInfo = s.data;

        var appString = "Abraca Calendar";

        if (packageInfo != null) {
          final version = packageInfo.version;
          final buildNumber = packageInfo.buildNumber;

          appString = "Abraca Calendar $version ($buildNumber)";
        }

        return Text(
          appString,
          style: const TextStyle(color: Colors.grey),
        );
      });
}

@swidget
Widget _copyright(BuildContext context) {
  return FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, AsyncSnapshot<PackageInfo> s) {
        final packageInfo = s.data;

        var versionString = "";

        if (packageInfo != null) {
          final version = packageInfo.version;
          final buildNumber = packageInfo.buildNumber;

          versionString = "$version ($buildNumber)";
        }
        return Column(
          children: [
            Text(
              versionString,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
            const Text(
              "Copyright @ Abraca Apps 2022",
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
          ],
        );
      });
}

@swidget
Widget _aboutPage(BuildContext context) {
  final theme = Theme.of(context);

  const intro =
      "Abraca Calendar is a calendar app focused on privacy enhancement.";
  return Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 30),
            const Text(intro,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                )),
            const Spacer(),
            const _Copyright(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}
