import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ScrollRefreshLayout extends MultiChildRenderObjectWidget {
  ScrollRefreshLayout({
    super.key,
    required Widget indicator,
    required Widget scrollable,
    required this.refreshPull,
  }) : super(children: [indicator, scrollable]);

  final double refreshPull;

  @override
  ScrollRefreshRenderBox createRenderObject(BuildContext context) =>
      ScrollRefreshRenderBox(refreshPull: refreshPull);

  @override
  void updateRenderObject(
      BuildContext context, ScrollRefreshRenderBox renderObject) {
    renderObject.refreshPull = refreshPull;
  }
}

class ScrollRefreshRenderBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  ScrollRefreshRenderBox({double refreshPull = 0.0})
      : _refreshPull = refreshPull;

  double get refreshPull => _refreshPull;
  double _refreshPull;

  set refreshPull(double value) {
    if (value == _refreshPull) return;
    _refreshPull = value;
    markNeedsLayout();
  }

  // Children order: [indicator, scrollable]
  RenderBox get _indicatorBox => firstChild!;
  RenderBox get _scrollableBox => lastChild!;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
    }
  }

  @override
  void performLayout() {
    _scrollableBox.layout(constraints, parentUsesSize: true);
    size = _scrollableBox.size;

    (_scrollableBox.parentData! as MultiChildLayoutParentData).offset =
        Offset(0, _refreshPull);

    _indicatorBox.layout(constraints.loosen());
    (_indicatorBox.parentData! as MultiChildLayoutParentData).offset =
        Offset.zero;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _scrollableBox.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _scrollableBox.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _scrollableBox.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _scrollableBox.getMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  bool hitTestChildren(HitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result as BoxHitTestResult, position: position);

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
