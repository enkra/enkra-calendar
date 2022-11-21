import 'package:flutter/material.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:ical/serializer.dart';
import 'package:provider/provider.dart';
import "package:collection/collection.dart";
import 'package:intl/intl.dart';

import 'common.dart';
import 'tab_page.dart';
import 'editing.dart';
import '../calendar.dart';
import '../date.dart';

part 'inbox.g.dart';

Widget buildInboxPage(
  BuildContext context, {
  required ValueNotifier<PageIndex> pageIndex,
}) {
  return TabPage(
    tabIndex: pageIndex.value.index,
    body: const Inbox(),
    appBar: AppBar(
      title: const Text('Inbox'),
      elevation: 0.3,
    ),
    onIndexChanged: (index) {
      pageIndex.value = PageIndex.values[index];
    },
  );
}

@swidget
Widget inbox(BuildContext context) {
  return Column(children: [
    Expanded(
      child:
          Consumer<CalendarManager>(builder: (context, calendarManager, child) {
        final notes = calendarManager.inboxNotes();

        final groupedNotes =
            groupBy<InboxNote, Date>(notes, (n) => Date.fromTime(n.time));

        List<Widget> noteItems = [];
        for (var d in groupedNotes.keys) {
          noteItems.add(_Time(date: d));

          final notes = groupedNotes[d]!.map((n) => _TextTask(note: n));

          noteItems.addAll(notes);
        }

        return ListView(
          padding: const EdgeInsets.only(
            left: 32,
            right: 32,
            top: 16,
          ),
          children: noteItems,
        );
      }),
    ),
    const _Input(),
  ]);
}

@swidget
Widget _textTask(BuildContext context, {required InboxNote note}) {
  final theme = Theme.of(context);

  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: EventContainer(
      backgroundColor:
          Color.alphaBlend(theme.primaryColor.withOpacity(0.05), Colors.white),
      leadingColor: Colors.transparent,
      child: Text(
        note.content,
        textAlign: TextAlign.justify,
        maxLines: 10,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
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
                    child: const Text('Schedule'),
                    onPressed: () async {
                      Navigator.pop(context);

                      var content = note.content;
                      if (content.length > 16) {
                        content = note.content.substring(0, 16);
                      }

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EditingPage(
                                  initialDay: Date.fromTime(DateTime.now()),
                                  eventToEdit: IEvent(
                                    status: IEventStatus.CONFIRMED,
                                    start: DateTime.now(),
                                    summary: content,
                                    description: note.content,
                                  ),
                                )),
                      );

                      if (result ?? false) {
                        calendarManager.deleteNote(note.id);
                      }
                    },
                  ),
                  SimpleDialogOption(
                    child: const Text('Delete'),
                    onPressed: () {
                      calendarManager.deleteNote(note.id);
                      Navigator.pop(context);
                    },
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
Widget _input(BuildContext context) {
  final theme = Theme.of(context);

  final controller = TextEditingController();

  return SizedBox(
    height: 56,
    child: Material(
      type: MaterialType.card,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 16),
            Expanded(
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: "Type your todos",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (val) {
                    final calendarManager =
                        Provider.of<CalendarManager>(context, listen: false);
                    calendarManager.addNote(InboxNote(content: val));

                    controller.clear();
                  },
                ),
              ),
            )),
            const SizedBox(width: 16),
            const Icon(Icons.image_outlined, color: Colors.grey),
            const SizedBox(width: 16),
            const Icon(Icons.photo_camera_outlined, color: Colors.grey),
            const SizedBox(width: 16),
            const Icon(Icons.keyboard_voice_outlined, color: Colors.grey),
            const SizedBox(width: 16),
          ],
        ),
      ),
    ),
  );
}

@swidget
Widget _time(BuildContext context, {required Date date}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Center(
      child: Text(
        date.format(DateFormat("MMM d, y")),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
    ),
  );
}
