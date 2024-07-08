import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class CustomReorderableDragStartListener extends ReorderableDragStartListener {
  final bool draggingEnabled;

  const CustomReorderableDragStartListener({
    Key? key,
    required Widget child,
    required int index,
    required this.draggingEnabled,
  }) : super(key: key, child: child, index: index);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) =>
          draggingEnabled ? _startDragging(context, event) : null,
      child: child,
    );
  }

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
        delay: const Duration(milliseconds: 1), debugOwner: this);
  }

  void _startDragging(BuildContext context, PointerDownEvent event) {
    final SliverReorderableListState? list =
        SliverReorderableList.maybeOf(context);
    list?.startItemDragReorder(
      index: index,
      event: event,
      recognizer: createRecognizer(),
    );
  }
}
