import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photoline/src/scrollable/notification/pointer.dart';

class PhotolineScrollable extends Scrollable {
  const PhotolineScrollable({
    super.key,
    super.controller,
    super.physics,
    super.axisDirection,
    required super.viewportBuilder,
  });

  @override
  ScrollableState createState() => ScrollableExState();
}

class ScrollableExState extends ScrollableState {
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.kind != PointerDeviceKind.mouse &&
          event.kind != PointerDeviceKind.trackpad) {
        return;
      }
      final parent = context.findAncestorStateOfType<ScrollableExState>();
      if (isPointerPrevent) {
        isPointerPrevent = false;
        return;
      }
      if (parent != null) parent.isPointerPrevent = true;

      PhotolinePointerScrollNotification(
        event: event,
        context: context,
        metrics: position,
      ).dispatch(context);
    }
  }

  bool isPointerPrevent = false;

  @override
  void didChangeDependencies() {
    //print('☢️ didChangeDependencies');
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerSignal: _onPointerSignal,
        child: super.build(context),
      );
}
