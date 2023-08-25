import "package:collection/collection.dart";
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../calendar.dart';
import '../date.dart';
import 'common.dart';
import 'editing.dart';
import 'tab_page.dart';
import 'util.dart';

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

@hwidget
Widget __input(
  BuildContext context, {
  ValueChanged<String>? onNoteCreated,
}) {
  final theme = Theme.of(context);

  final controller = useRef(TextEditingController());

  return Material(
    type: MaterialType.card,
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: TextField(
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: 5,
                minLines: 1,
                controller: controller.value,
                decoration: const InputDecoration(
                  hintText: "Type your todos",
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          )),
          const SizedBox(width: 8),
          IconButton(
            padding: const EdgeInsets.all(0),
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            icon: const Icon(
              Icons.arrow_upward,
            ),
            color: theme.colorScheme.primary,
            onPressed: () {
              final content = controller.value.text;

              if (content == "") {
                return;
              }

              final calendarManager =
                  Provider.of<CalendarManager>(context, listen: false);
              calendarManager.addNote(InboxNote(content: content));

              controller.value.clear();

              onNoteCreated?.call(content);
            },
          ),
        ],
      ),
    ),
  );
}

@swidget
Widget __itemQuickMenu(
  BuildContext context, {
  required InboxNote note,
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
                'Schedule',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              leading: Icon(
                Icons.alarm_outlined,
                color: theme.colorScheme.primary,
              ),
              onTap: () async {
                Navigator.pop(context);

                final calendarManager =
                    Provider.of<CalendarManager>(context, listen: false);

                final event = calendarManager.createEventFromIndexNote(note);

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EditingPage(
                            initialDay: Date.today(),
                            eventToEdit: event,
                          )),
                );

                if (result ?? false) {
                  calendarManager.deleteNote(note.id);
                }
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

                copyToClipboardAutoClear(note.content);
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
                  content: "Delete this note?",
                  onOk: (context) {
                    final calendarManager =
                        Provider.of<CalendarManager>(context, listen: false);

                    calendarManager.deleteNote(note.id);
                  },
                );
              },
            )
          ],
        ),
      ));
}

@swidget
Widget __placeholder(
  BuildContext context,
) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          "assets/checklist.svg",
          width: 150,
          height: 150,
        ),
        const SizedBox(height: 15),
        const Text(
          "Empty inbox",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Note what you want to do here quickly",
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
        const Text(
          "and schedule them later.",
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    ),
  );
}

@swidget
Widget __textTask(BuildContext context, {required InboxNote note}) {
  final theme = Theme.of(context);

  onLongPress() {
    showMaterialModalBottomSheet(
      expand: false,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemQuickMenu(note: note),
    );
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: EventContainer(
      backgroundColor: theme.colorScheme.secondary,
      leadingColor: Colors.transparent,
      onLongPress: onLongPress,
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
    ),
  );
}

@swidget
Widget __time(BuildContext context, {required Date date}) {
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

class Inbox extends StatefulWidget {
  const Inbox({Key? key}) : super(key: key);

  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  ScrollController scrollController = ScrollController();

  bool suppressPointerUp = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerMove: (e) {
              final delta = e.delta;
              if (delta.dx.abs() > 1.5 || delta.dy.abs() > 1.5) {
                suppressPointerUp = true;
              }
            },
            onPointerUp: (_) {
              if (!suppressPointerUp) {
                FocusManager.instance.primaryFocus?.unfocus();
              }
              suppressPointerUp = false;
            },
            child: Column(
              children: [
                Flexible(
                  child: Consumer<CalendarManager>(
                    builder: (context, calendarManager, child) {
                      final notes = calendarManager.inboxNotes();
                      return FutureBuilder(
                          future: notes,
                          builder: (context, AsyncSnapshot<List<InboxNote>> f) {
                            final notes = f.data ?? [];

                            return renderContent(notes, scrollController);
                          });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        _Input(
          onNoteCreated: (_) {
            onNoteCreated(scrollController);
          },
        )
      ],
    );
  }

  onNoteCreated(scrollController) {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  renderContent(notes, scrollController) {
    if (notes.isEmpty) {
      return const _Placeholder();
    }

    // use double reversed list view to make
    // resizing UX more friendly
    // when keyboard popuping
    final noteItems = renderNotes(notes).reversed.toList();

    return ListView.builder(
      key: const PageStorageKey("Notes"),
      shrinkWrap: true,
      reverse: true,
      padding: const EdgeInsets.only(
        left: 32,
        right: 32,
        top: 16,
      ),
      itemCount: noteItems.length,
      itemBuilder: (context, index) {
        return noteItems[index];
      },
      controller: scrollController,
    );
  }

  renderNotes(notes) {
    final groupedNotes = groupBy<InboxNote, Date>(notes, (n) => n.time.date());

    List<Widget> noteItems = [];
    for (var d in groupedNotes.keys) {
      // add Time tag widgets
      noteItems.add(_Time(date: d));

      final notes = groupedNotes[d]!.map((n) => _TextTask(note: n));

      noteItems.addAll(notes);
    }

    return noteItems;
  }
}
