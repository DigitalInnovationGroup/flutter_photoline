import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photoline/library.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.mouse,
        PointerDeviceKind.unknown,
      };

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => switch (axisDirectionToAxis(details.direction)) {
        Axis.horizontal => child,
        Axis.vertical => details.controller is ScrollSnapController
            ? child
            : _Scrollbar(
                controller: details.controller,
                child: child,
              )
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics());
}

class _Scrollbar extends RawScrollbar {
  const _Scrollbar({
    required super.child,
    super.controller,
  }) : super(
        //fadeDuration: const Duration(milliseconds: 20),
        //timeToFade: const Duration(milliseconds: 20),
        );

  @override
  RawScrollbarState<_Scrollbar> createState() => _ScrollbarExState();
}

class _ScrollbarExState extends RawScrollbarState<_Scrollbar> {
  @override
  void updateScrollbarPainter() {
    scrollbarPainter
      ..color = widget.thumbColor ?? const Color(0x66BCBCBC)
      ..textDirection = Directionality.of(context)
      ..thickness = widget.thickness ?? 6
      ..radius = widget.radius
      ..padding = EdgeInsets.zero
      ..scrollbarOrientation = widget.scrollbarOrientation
      ..mainAxisMargin = widget.mainAxisMargin
      ..crossAxisMargin = widget.crossAxisMargin
      ..minLength = widget.minThumbLength
      ..minOverscrollLength = widget.minOverscrollLength ?? widget.minThumbLength;
  }
}
