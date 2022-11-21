import 'package:flutter/material.dart';
import 'package:functional_widget_annotation/functional_widget_annotation.dart';

part 'common.g.dart';

@swidget
Widget eventContainer(
  BuildContext context, {
  required Widget child,
  Color? leadingColor,
  Color? backgroundColor,
  GestureLongPressCallback? onLongPress,
}) {
  leadingColor = leadingColor ?? Colors.grey[200];
  backgroundColor = backgroundColor ?? Colors.grey[100];

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
    ),
    width: double.infinity,
    child: Material(
      color: backgroundColor,
      type: MaterialType.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => {},
        onLongPress: onLongPress,
        child: IntrinsicHeight(
          child: Stack(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: child,
              ),
              Container(
                decoration: BoxDecoration(
                  color: leadingColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                width: 8,
                height: double.infinity,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
