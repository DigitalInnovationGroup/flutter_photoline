import 'package:flutter/widgets.dart';

/// Shared pull-to-refresh state used by both ScrollSnapController] (standalone)
/// and ScrollSnapHeaderController] (header-based). The scroll position writes
/// [refreshPull] when the user overscrolls; the widget layer reads it to render
/// the indicator and animate collapse.
mixin ScrollRefreshMixin {
  final refreshPull = ValueNotifier<double>(0.0);
  bool canRefresh = false;
  bool refreshing = false;
  double refreshTriggerExtent = 60.0;
}
