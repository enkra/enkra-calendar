import 'package:flutter/material.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';

import 'common.dart';
import 'tab_page.dart';

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
      child: ListView(
        padding: const EdgeInsets.only(
          left: 32,
          right: 32,
          top: 16,
        ),
        children: const [
          _TextTask("Meeting with Josh"),
          _TextTask("Clean room"),
          _TextTask("Shopping"),
          _Time(),
          _TextTask("Do math homework"),
          _TextTask(
              "Lorem Ipsum is simply dummy text of the printing and typesetting industry."
              " Lorem Ipsum has been the industry's standard dummy text ever since the 1500s,"
              " when an unknown printer took a galley of type and scrambled it to make a type"
              " specimen book. It has survived not only five centuries, but also the leap into"
              " electronic typesetting, remaining essentially unchanged. It was popularised in"
              " the 1960s with the release of Letraset sheets containing Lorem Ipsum passages,"
              " and more recently with desktop publishing software like Aldus PageMaker"
              " including versions of Lorem Ipsum."),
        ],
      ),
    ),
    const _Input(),
  ]);
}

@swidget
Widget _textTask(BuildContext context, String content) {
  final theme = Theme.of(context);

  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: EventContainer(
      backgroundColor:
          Color.alphaBlend(theme.primaryColor.withOpacity(0.05), Colors.white),
      leadingColor: Colors.transparent,
      child: Text(
        content,
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
Widget _input(BuildContext context) {
  final theme = Theme.of(context);

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
              child: const Center(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Type your todos",
                    border: InputBorder.none,
                  ),
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
Widget _time(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Center(
      child: Text(
        "20:00",
        style: TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
    ),
  );
}
