import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:photoline/src/scroll/snap/refresh/mixin.dart';

enum ScrollSnapHeaderInitialState { expanded, collapsed }

class ScrollSnapHeaderController with ScrollRefreshMixin {
  ScrollSnapHeaderController({
    this.initialState = ScrollSnapHeaderInitialState.expanded,
  });

  final ScrollSnapHeaderInitialState initialState;

  double get minHeight => 200;
  double get maxHeight => 400;

  late final height = ValueNotifier<double>(
    initialState == ScrollSnapHeaderInitialState.expanded ? maxHeight : minHeight,
  );

  set delta(double delta) {
    height.value = clampDouble(height.value - delta, minHeight, maxHeight);
  }

  ScrollController? activeScrollController;
}
