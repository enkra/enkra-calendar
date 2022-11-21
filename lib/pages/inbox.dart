import 'package:flutter/material.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';
import 'package:provider/provider.dart';
import "package:collection/collection.dart";
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

class Inbox extends StatelessWidget {
  const Inbox({Key? key}) : super(key: key);

  renderNotes(notes) {
    final groupedNotes =
        groupBy<InboxNote, Date>(notes, (n) => Date.fromTime(n.time));

    List<Widget> noteItems = [];
    for (var d in groupedNotes.keys) {
      // add Time tag widgets
      noteItems.add(_Time(date: d));

      final notes = groupedNotes[d]!.map((n) => _TextTask(note: n));

      noteItems.addAll(notes);
    }

    return noteItems;
  }

  renderContent(notes, scrollController) {
    if (notes.isEmpty) {
      return const _Placeholder();
    } else {
      final noteItems = renderNotes(notes);

      return ListView.builder(
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
  }

  onNoteCreated(scrollController) {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    return Column(children: [
      Expanded(
        child: Consumer<CalendarManager>(
            builder: (context, calendarManager, child) {
          final notes = calendarManager.inboxNotes();
          return FutureBuilder(
              future: notes,
              builder: (context, AsyncSnapshot<List<InboxNote>> f) {
                final notes = f.data ?? [];

                return renderContent(notes, scrollController);
              });
        }),
      ),
      _Input(
        onNoteCreated: (_) {
          onNoteCreated(scrollController);
        },
      ),
    ]);
  }
}

@swidget
Widget __textTask(BuildContext context, {required InboxNote note}) {
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

                      final event =
                          calendarManager.createEventFromIndexNote(note);

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EditingPage(
                                  initialDay: Date.fromTime(DateTime.now()),
                                  eventToEdit: event,
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
Widget __input(
  BuildContext context, {
  ValueChanged<String>? onNoteCreated,
}) {
  final theme = Theme.of(context);

  final controller = TextEditingController();

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
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: TextField(
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: 5,
                minLines: 1,
                controller: controller,
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
              final content = controller.text;

              if (content == "") {
                return;
              }

              final calendarManager =
                  Provider.of<CalendarManager>(context, listen: false);
              calendarManager.addNote(InboxNote(content: content));

              controller.clear();

              onNoteCreated?.call(content);
            },
          ),
        ],
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

@swidget
Widget __placeholder(
  BuildContext context,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset("assets/checklist.svg"),
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
                "and shedule them later.",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
