import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photoline/library.dart';
import 'package:photoline/src/scroll/snap/snap/position.dart';

State? _getState() => null;

class ScrollSnapController extends ScrollController with ScrollRefreshMixin {
  ScrollSnapController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
    this.getState = _getState,
    this.snapLastMax = false,
    this.snapLastMin = false,
    this.headerHolder,
    this.onReload,
    this.snapCan,
    this.snapBuilder,
    this.snapTop = true,
    this.snapArea = false,
    this.freeMaxExtend = false,
    this.snapGap = 0,
  }) {
    if (onReload != null) canRefresh = true;
  }

  final State? Function() getState;

  @override
  void dispose() {
    refreshPull.dispose();
    super.dispose();
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    double initital = 0;

    if (headerHolder != null) {
      initital = -headerHolder!.height.value;
    }

    return ScrollSnapPosition(
      controller: this,
      physics: physics,
      context: context,
      initialPixels: initital,
      oldPosition: oldPosition,
    );
  }

  BoxConstraints? boxConstraints;

  final bool snapLastMin;
  final bool snapLastMax;

  final double snapGap;
  final bool snapArea;
  final bool snapTop;

  final bool freeMaxExtend;

  final ItemExtentBuilder? snapBuilder;
  final bool? Function(int index, SliverLayoutDimensions dimensions)? snapCan;

  final RefreshCallback? onReload;
  final isUserDrag = ValueNotifier<bool>(false);

  final ScrollSnapHeaderController? headerHolder;

  ScrollSnapSpringSimulation? simulation;

  @override
  ScrollSnapPosition get position => super.position as ScrollSnapPosition;

  double keyboardOverlap = 0;
}
