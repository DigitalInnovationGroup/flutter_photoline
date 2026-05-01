import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:photoline/library.dart';

/// [PageView], [ScrollPositionWithSingleContext], [ScrollPosition]
class ScrollSnapPosition extends ViewportOffset with ScrollMetrics implements ScrollPosition, ScrollActivityDelegate {
  ScrollSnapPosition({
    required this.controller,
    required this.physics,
    required this.context,
    ScrollPosition? oldPosition,
    double? initialPixels = 0.0,
  }) {
    if (oldPosition != null) {
      absorb(oldPosition);
    }

    if (keepScrollOffset) {
      restoreScrollOffset();
    }
    // If oldPosition is not null, the superclass will first call absorb(),
    // which may set _pixels and _activity.
    if (!hasPixels && initialPixels != null) {
      correctPixels(initialPixels);
    }
    if (activity == null) {
      goIdle();
    }
    assert(activity != null);
  }

  @override
  final ScrollPhysics physics;
  @override
  final ScrollContext context;

  final ScrollSnapController controller;

  @override
  AxisDirection get axisDirection => context.axisDirection;

  @override
  ScrollDirection get userScrollDirection => _userScrollDirection;
  ScrollDirection _userScrollDirection = ScrollDirection.idle;

  @override
  double get minScrollExtent => _minScrollExtent!;
  double? _minScrollExtent;

  @override
  double get maxScrollExtent => _maxScrollExtent!;
  double? _maxScrollExtent;

  @override
  bool get hasContentDimensions => _minScrollExtent != null && _maxScrollExtent != null;

  double _impliedVelocity = 0;

  @override
  double get pixels => _pixels!;
  double? _pixels;

  @override
  bool get hasPixels => _pixels != null;

  @override
  double get viewportDimension => _viewportDimension!;
  double? _viewportDimension;

  @override
  bool get hasViewportDimension => _viewportDimension != null;

  @override
  bool get haveDimensions => _haveDimensions;
  bool _haveDimensions = false;

  @override
  bool get shouldIgnorePointer => !outOfRange && (activity?.shouldIgnorePointer ?? true);

  // === Photoline
  int _photolineLastScrollIndex = 0;

  bool get photolineCanSnap {
    final double? mw = controller.boxConstraints?.maxWidth;
    final double? vd = _viewportDimension;
    if (mw == null || vd == null) return false;
    return controller.snapBuilder != null;
  }

  void photolineScrollToOpen(double delta) {
    if (!photolineCanSnap) return;

    unawaited(
      animateTo(
        pixels - delta,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeIn,
      ),
    );
  }

  void photolineScrollToNext(int direction) {
    if (controller.snapBuilder == null) return;

    double dist = double.infinity;
    double so = 0;
    var current = -1;
    final List<double> offsets = [];

    final mw = controller.boxConstraints!.maxWidth;
    final vd = _viewportDimension!;

    // When a header is present, include the header's fully-expanded position
    // as the first offset so navigation can reach it.
    if (controller.headerHolder != null && hasContentDimensions) {
      offsets.add(minScrollExtent);
      final d = minScrollExtent - pixels;
      if (dist.isInfinite || d.abs() < dist.abs()) {
        dist = d;
        current = 0;
      }
    }

    for (var i = 0; i >= 0; i++) {
      final pix = controller.snapBuilder!(
        i,
        SliverLayoutDimensions(
          scrollOffset: 0,
          precedingScrollExtent: 0,
          viewportMainAxisExtent: vd,
          crossAxisExtent: mw,
        ),
      );
      if (pix == null) break;

      final d = so - pixels;
      offsets.add(so);
      if (dist.isInfinite || d.abs() < dist.abs()) {
        dist = d;
        current = offsets.length - 1;
      }
      so += pix;
    }

    current += direction;

    if (current < 0 || current >= offsets.length) return;

    //unawaited(animateTo(offsets[current],duration: const Duration(milliseconds: 300), curve: Curves.linear));
    beginActivity(
      BallisticScrollActivity(
        this,
        ScrollSpringSimulation(
          SpringDescription.withDampingRatio(
            mass: 1.2,
            stiffness: 80.0,
            ratio: 1.2,
          ),
          pixels,
          offsets[current],
          0,
          tolerance: physics.toleranceFor(this),
        ),
        context.vsync,
        activity?.shouldIgnorePointer ?? true,
      ),
    );
  }

  (int index, double target, double height) _photolineClosestTop(
    double newPixels,
  ) {
    if (!photolineCanSnap) return (0, 0, 0);

    final mw = controller.boxConstraints!.maxWidth;
    final vd = _viewportDimension!;

    double dist = double.infinity;
    double so = 0;
    var index = 0;
    double target = 0;
    double height = 0;

    for (var i = 0; i >= 0; i++) {
      final d = so - newPixels;
      final h = controller.snapBuilder!(
        i,
        SliverLayoutDimensions(
          scrollOffset: 0,
          precedingScrollExtent: 0,
          viewportMainAxisExtent: vd,
          crossAxisExtent: mw,
        ),
      );
      if (h == null) break;

      if (dist.isInfinite || d.abs() < dist.abs()) {
        dist = d;
        index = i;
        target = so;
        height = h;
      }
      so += h;
    }
    _photolineLastScrollIndex = index;

    return (index, target, height);
  }

  double? photolinePhysicSnap(double velocity, double target) {
    if (!photolineCanSnap) return null;

    final mw = controller.boxConstraints!.maxWidth;
    final vd = _viewportDimension!;

    bool viewport(double a) => a - controller.snapGap <= vd;

    double so = 0;
    final List<(double, double)> offsets = [];
    var hasOverflow = false;

    final dim = SliverLayoutDimensions(
      scrollOffset: 0,
      precedingScrollExtent: 0,
      viewportMainAxisExtent: vd,
      crossAxisExtent: mw,
    );

    for (var i = 0; i >= 0; i++) {
      final h = controller.snapBuilder!(i, dim);
      if (h == null) break;
      if (!viewport(h)) hasOverflow = true;
      offsets.add((so, h));
      so += h;
    }

    if (velocity == 0) {
      return target;
    }

    // Clamp the fling target so it does not go beyond the fully expanded header.
    if (controller.headerHolder != null && hasContentDimensions) {
      target = math.max(target, -controller.headerHolder!.maxHeight);
    }

    if (hasOverflow) {
      if (!kProfileMode) return target;

      final List<double> anchors = [];
      for (var i = 0; i < offsets.length; i++) {
        final (so, h) = offsets[i];
        if (!viewport(h)) continue;
        anchors.add(so);
      }

      if (velocity > 0) {
        for (var i = 0; i < anchors.length; i++) {
          final a = anchors[i];
          if (a < target) continue; //⬆️
          return (a - target).abs() > vd ? target : a;
        }
      } else {
        for (int i = anchors.length - 1; i >= 0; i--) {
          final a = anchors[i];
          if (a > target) continue; //⬇️
          return (a - target).abs() > vd ? target : a;
        }
      }
    } else {
      for (int i = offsets.length - 1; i >= 0; i--) {
        final (so, h) = offsets[i];
        if (velocity > 0) {
          if (target < so) continue; //⬆️
          return so + h;
        } else {
          if (target < so) continue; //⬇️
          return so;
        }
      }
    }
    return target;
  }

  // === Position

  @override
  bool applyViewportDimension(double viewportDimension) {
    //print('🍒 applyViewportDimension');

    final double? oldViewportDimensions = hasViewportDimension ? this.viewportDimension : null;
    if (viewportDimension == oldViewportDimensions) {
      return true;
    }

    if (_viewportDimension != viewportDimension) {
      _viewportDimension = viewportDimension;
      _didChangeViewportDimensionOrReceiveCorrection = true;
    }

    /// snap photolines
    if (controller.snapBuilder != null) {
      final double? oldPixels = hasPixels ? pixels : null;

      double newPixels = 0;

      final mw = controller.boxConstraints!.maxWidth;

      final dim = SliverLayoutDimensions(
        scrollOffset: 0,
        precedingScrollExtent: 0,
        viewportMainAxisExtent: viewportDimension,
        crossAxisExtent: mw,
      );

      for (var i = 0; i >= 0; i++) {
        final h = controller.snapBuilder!(i, dim);
        if (h == null) break;
        if (i == _photolineLastScrollIndex) break;
        newPixels += h;
      }

      // Account for header offset: when header is present, the scroll
      // position includes the negative header extent.
      if (controller.headerHolder != null) {
        newPixels -= controller.headerHolder!.height.value;
      }

      if (newPixels != oldPixels) {
        correctPixels(newPixels);
        return false;
      }
    }

    return true;
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final dim = SliverLayoutDimensions(
      scrollOffset: 0,
      precedingScrollExtent: 0,
      viewportMainAxisExtent: _viewportDimension!,
      crossAxisExtent: controller.boxConstraints!.maxWidth,
    );

    /// Snap Last Min: events
    if (controller.snapLastMin && _viewportDimension != null) {
      final List<double> sizes = [];
      double allh = 0;

      for (var i = 0; i >= 0; i++) {
        final h = controller.snapBuilder!(i, dim);
        if (h == null) break;
        if (h == 0) continue;
        sizes.add(allh);
        allh += h;
      }

      for (final so in sizes) {
        if (allh - so <= viewportDimension) {
          maxScrollExtent = math.max(maxScrollExtent, so);
          break;
        }
      }
    }

    /// Snap Last Max: photolines
    if (controller.snapLastMax && _viewportDimension != null) {
      double so = 0;
      for (var i = 0; i >= 0; i++) {
        if (controller.snapBuilder!(i + 1, dim) == null) {
          break;
        }
        final h = controller.snapBuilder!(i, dim);
        if (h == null) break;
        so += h;
      }
      maxScrollExtent = math.max(maxScrollExtent, so);
    }

    maxScrollExtent += controller.keyboardOverlap;

    if (controller.freeMaxExtend) {
      maxScrollExtent = math.max(pixels, maxScrollExtent);
      //minScrollExtent
    }

    if (controller.headerHolder != null) {
      final h = controller.headerHolder!;
      minScrollExtent -= h.maxHeight;
      //maxScrollExtent += e;
    }

    assert(haveDimensions == (_lastMetrics != null));
    if (!nearEqual(
          _minScrollExtent,
          minScrollExtent,
          Tolerance.defaultTolerance.distance,
        ) ||
        !nearEqual(
          _maxScrollExtent,
          maxScrollExtent,
          Tolerance.defaultTolerance.distance,
        ) ||
        _didChangeViewportDimensionOrReceiveCorrection) {
      //assert(minScrollExtent <= maxScrollExtent);
      _minScrollExtent = minScrollExtent;
      _maxScrollExtent = maxScrollExtent;

      final ScrollMetrics? currentMetrics = haveDimensions ? copyWith() : null;
      _didChangeViewportDimensionOrReceiveCorrection = false;
      _pendingDimensions = true;
      if (haveDimensions && !correctForNewDimensions(_lastMetrics!, currentMetrics!)) {
        return false;
      }
      _haveDimensions = true;
    }
    assert(haveDimensions);
    if (_pendingDimensions) {
      applyNewDimensions();
      _pendingDimensions = false;
    }
    assert(
      !_didChangeViewportDimensionOrReceiveCorrection,
      'Use correctForNewDimensions() (and return true) to change the scroll offset during applyContentDimensions().',
    );

    if (_isMetricsChanged()) {
      // It is too late to send useful notifications, because the potential
      // listeners have, by definition, already been built this frame. To make
      // sure the notification is sent at all, we delay it until after the frame
      // is complete.
      if (!_haveScheduledUpdateNotification) {
        scheduleMicrotask(didUpdateScrollMetrics);
        _haveScheduledUpdateNotification = true;
      }
      _lastMetrics = copyWith();
    }
    return true;
  }

  /// After [applyViewportDimension] or [applyContentDimensions]
  @override
  void applyNewDimensions() {
    //print('💩 applyNewDimensions');
    if (activity is BallisticScrollActivity) return;
    assert(hasPixels);
    assert(_pendingDimensions);
    activity!.applyNewDimensions();
    context.setCanDrag(physics.shouldAcceptUserOffset(this));
  }

  @override
  void absorb(ScrollPosition other) {
    assert(other.context == context);
    assert(_pixels == null);
    if (other.hasContentDimensions) {
      _minScrollExtent = other.minScrollExtent;
      _maxScrollExtent = other.maxScrollExtent;
    }
    if (other.hasPixels) {
      _pixels = other.pixels;
    }
    if (other.hasViewportDimension) {
      _viewportDimension = other.viewportDimension;
    }

    assert(activity == null);
    assert(other.activity != null);
    _activity = other.activity;
    if (other is ScrollSnapPosition) {
      other._activity = null;
    }
    if (other.runtimeType != runtimeType) {
      activity!.resetActivity();
    }
    context.setIgnorePointer(activity!.shouldIgnorePointer);
    isScrollingNotifier.value = activity!.isScrolling;

    if (other is! ScrollSnapPosition) {
      goIdle();
      return;
    }
    activity!.updateDelegate(this);

    _userScrollDirection = other._userScrollDirection;
    assert(_currentDrag == null);
    if (other._currentDrag != null) {
      _currentDrag = other._currentDrag;
      _currentDrag!.updateDelegate(this);
      other._currentDrag = null;
    }
  }

  @override
  double get devicePixelRatio => context.devicePixelRatio;

  @override
  double setPixels(double newPixels) {
    final delta = newPixels - pixels;
    if (delta == 0) return _setPixels(newPixels);

    if (controller.headerHolder != null && hasContentDimensions) {
      final holder = controller.headerHolder!;
      final min = minScrollExtent;

      // ── Refresh pull handling ──────────────────────────────────────────
      // When canRefresh is set, redirect overscroll below minScrollExtent
      // into the refresh pull indicator, and consume upward scroll to
      // reduce the pull before scrolling content.
      if (holder.canRefresh) {
        final currentPull = holder.refreshPull.value;

        if (currentPull > 0 && delta > 0) {
          // User is dragging/scrolling up while the refresh indicator is
          // showing – consume the delta to reduce the pull first.
          // This applies even during refreshing to prevent content from
          // rendering on top of the refresh indicator.
          if (!holder.refreshing) {
            final consume = math.min(delta, currentPull);
            holder.refreshPull.value = currentPull - consume;
            newPixels = pixels + (delta - consume);
            if ((newPixels - pixels).abs() < precisionErrorTolerance) {
              return 0.0;
            }
            // Continue with the remaining delta for header/content.
          } else {
            // While refreshing, block upward scroll so content stays below
            // the indicator — do not allow pixels to increase past current.
            return 0.0;
          }
        } else if (delta < 0 && newPixels < min) {
          // Dragging/flinging down below minScrollExtent.
          // Only accumulate refreshPull when the user is actively dragging —
          // never during a ballistic (inertial) phase.
          final isBallistic = activity is BallisticScrollActivity;
          if (!holder.refreshing && !isBallistic) {
            // Redirect the excess below min into the refresh pull with
            // rubber-band friction: more pull → less effect.
            final excess = min - newPixels;
            final friction = 1.0 - (currentPull / (holder.refreshTriggerExtent * 3.0)).clamp(0.0, 0.8);
            holder.refreshPull.value = currentPull + excess * friction;
          }
          // Always clamp to min — never let the scroll position go below it.
          newPixels = min;
          if ((newPixels - pixels).abs() < precisionErrorTolerance) {
            return 0.0;
          }
        }
      }

      // ── Header height adjustment ───────────────────────────────────────
      // Don't adjust the header when in overscroll territory (below
      // minScrollExtent). The header should only expand/collapse within
      // the normal scroll range, not during overscroll bounce-back.
      final double clampedPixels = math.max(pixels, min);
      final double clampedNew = math.max(newPixels, min);
      final double clampedDelta = clampedNew - clampedPixels;

      if (clampedDelta != 0) {
        final double headerThreshold = -holder.minHeight;
        final double headerDelta;
        if (clampedPixels <= headerThreshold && clampedNew <= headerThreshold) {
          // Fully inside the header expansion zone.
          headerDelta = clampedDelta;
        } else if (clampedPixels > headerThreshold && clampedNew <= headerThreshold) {
          // Scrolling up past the content/header boundary.
          headerDelta = clampedNew - headerThreshold;
        } else if (clampedPixels <= headerThreshold && clampedNew > headerThreshold) {
          // Scrolling down past the boundary into content.
          headerDelta = -(clampedPixels - headerThreshold);
        } else {
          // Both above threshold — fully in content, no header interaction.
          headerDelta = 0;
        }

        if (headerDelta != 0) {
          final oldHeight = holder.height.value;
          holder.height.value = clampDouble(
            oldHeight - headerDelta,
            holder.minHeight,
            holder.maxHeight,
          );
        }
      }
    }

    assert(activity!.isScrolling);
    return _setPixels(newPixels);
  }

  double _setPixels(double newPixels) {
    final (pI, _, _) = _photolineClosestTop(newPixels);
    _photolineLastScrollIndex = pI;

    if (newPixels != pixels) {
      final double overscroll = applyBoundaryConditions(newPixels);
      final double oldPixels = pixels;
      _pixels = newPixels - overscroll;
      if (_pixels != oldPixels) {
        if (outOfRange) {
          context.setIgnorePointer(false);
        }
        notifyListeners();
        didUpdateScrollPositionBy(pixels - oldPixels);
      }
      if (overscroll.abs() > precisionErrorTolerance) {
        didOverscrollBy(overscroll);
        return overscroll;
      }
    }
    return 0.0;
  }

  @override
  void correctPixels(double value) {
    _pixels = value;
  }

  @override
  void correctBy(double correction) {
    //print('✅ correct | $correction');
    _pixels = _pixels! + correction;
    _didChangeViewportDimensionOrReceiveCorrection = true;
  }

  @override
  void forcePixels(double value) {
    assert(hasPixels);
    _impliedVelocity = value - pixels;
    _pixels = value;
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _impliedVelocity = 0;
    }, debugLabel: 'ScrollPosition.resetVelocity');
  }

  @override
  void saveScrollOffset() {}

  @override
  void restoreScrollOffset() {}

  @override
  void restoreOffset(double offset, {bool initialRestore = false}) {}

  @override
  void saveOffset() {}

  @override
  double applyBoundaryConditions(double value) {
    assert(value != pixels);
    final pp = pixels;
    final min = minScrollExtent;
    final max = maxScrollExtent;

    // Allow bouncing underscroll only when using sliver-based refresh
    // (not when header manages the refresh indicator via setPixels).
    if (controller.onRefresh != null && value < pp && pp <= min && controller.headerHolder == null) {
      return 0.0; // Bouncing underscroll (sliver-based refresh only)
    }

    late final double result;

    if (value < pp && pp <= min) {
      result = value - pp; // Underscroll.
    } else if (max <= pp && pp < value) {
      result = value - pp; // Overscroll.
    } else if (value < min && min < pp) {
      result = value - min; // Hit top edge.
    } else if (pp < max && max < value) {
      result = value - max; // Hit bottom edge.
    } else {
      result = 0.0;
    }
    final double delta = value - pixels;
    assert(result.abs() <= delta.abs());

    return result;
  }

  bool _didChangeViewportDimensionOrReceiveCorrection = true;

  bool _pendingDimensions = false;
  ScrollMetrics? _lastMetrics;

  bool _haveScheduledUpdateNotification = false;

  bool _isMetricsChanged() {
    assert(haveDimensions);
    final ScrollMetrics currentMetrics = copyWith();
    return _lastMetrics == null ||
        !(currentMetrics.extentBefore == _lastMetrics!.extentBefore && //
            currentMetrics.extentInside == _lastMetrics!.extentInside &&
            currentMetrics.extentAfter == _lastMetrics!.extentAfter &&
            currentMetrics.axisDirection == _lastMetrics!.axisDirection);
  }

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    if (!kProfileMode) {
      return true;
    }

    final double newPixels = physics.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: activity!.isScrolling,
      velocity: activity!.velocity,
    );

    if (newPixels != pixels) {
      correctPixels(newPixels);
      return false;
    }
    return true;
  }

  ScrollPositionAlignmentPolicy _maybeFlipAlignment(
    ScrollPositionAlignmentPolicy alignmentPolicy,
  ) {
    return switch (alignmentPolicy) {
      // Don't flip when explicit.
      ScrollPositionAlignmentPolicy.explicit => alignmentPolicy,
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd => ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart => ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    };
  }

  ScrollPositionAlignmentPolicy _applyAxisDirectionToAlignmentPolicy(
    ScrollPositionAlignmentPolicy alignmentPolicy,
  ) {
    return switch (axisDirection) {
      // Start and end alignments must account for axis direction.
      // When focus is requested for example, it knows the directionality of the
      // keyboard keys initiating traversal, but not the direction of the
      // Scrollable.
      AxisDirection.up || AxisDirection.left => _maybeFlipAlignment(alignmentPolicy),
      AxisDirection.down || AxisDirection.right => alignmentPolicy,
    };
  }

  @override
  Future<void> ensureVisible(
    RenderObject object, {
    double alignment = 0.0,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
    ScrollPositionAlignmentPolicy alignmentPolicy = ScrollPositionAlignmentPolicy.explicit,
    RenderObject? targetRenderObject,
  }) async {
    assert(object.attached);
    final RenderAbstractViewport? viewport = RenderAbstractViewport.maybeOf(
      object,
    );

    if (viewport == null) return;

    Rect? targetRect;
    if (targetRenderObject != null && targetRenderObject != object) {
      targetRect = MatrixUtils.transformRect(
        targetRenderObject.getTransformTo(object),
        object.paintBounds.intersect(targetRenderObject.paintBounds),
      );
    }

    double target;
    switch (_applyAxisDirectionToAlignmentPolicy(alignmentPolicy)) {
      case ScrollPositionAlignmentPolicy.explicit:
        target = viewport
            .getOffsetToReveal(
              object,
              alignment,
              rect: targetRect,
              axis: axis,
            )
            .offset;
        target = clampDouble(target, minScrollExtent, maxScrollExtent);
      case ScrollPositionAlignmentPolicy.keepVisibleAtEnd:
        target = viewport
            .getOffsetToReveal(
              object,
              1.0, // Aligns to end
              rect: targetRect,
              axis: axis,
            )
            .offset;
        target = clampDouble(target, minScrollExtent, maxScrollExtent);
        if (target < pixels) {
          target = pixels;
        }
      case ScrollPositionAlignmentPolicy.keepVisibleAtStart:
        target = viewport
            .getOffsetToReveal(
              object,
              0.0, // Aligns to start
              rect: targetRect,
              axis: axis,
            )
            .offset;
        target = clampDouble(target, minScrollExtent, maxScrollExtent);
        if (target > pixels) {
          target = pixels;
        }
    }

    if (target == pixels) return;

    if (duration == Duration.zero) {
      jumpTo(target);
      return;
    }

    return animateTo(target, duration: duration, curve: curve);
  }

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) {
    if (nearEqual(to, pixels, physics.toleranceFor(this).distance)) {
      // Skip the animation, go straight to the position as we are already close.
      jumpTo(to);
      return Future<void>.value();
    }

    final activity = DrivenScrollActivity(
      this,
      from: pixels,
      to: to,
      duration: duration,
      curve: curve,
      vsync: context.vsync,
    );
    beginActivity(activity);
    return activity.done;
  }

  @override
  void jumpTo(double pixels) {
    goIdle();
    if (this.pixels != pixels) {
      final double oldPixels = this.pixels;
      forcePixels(pixels);
      didStartScroll();
      didUpdateScrollPositionBy(this.pixels - oldPixels);
      didEndScroll();
    }
    goBallistic(0.0);
  }

  @override
  void jumpToWithoutSettling(double value) {}

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      goBallistic(0.0);
      return;
    }
    final double velocity = (math.max(delta.abs(), 50) * delta.sign) * 10;
    goBallistic(velocity);
  }

  @override
  Future<void> moveTo(
    double to, {
    Duration? duration,
    Curve? curve,
    bool? clamp = true,
  }) {
    assert(clamp != null);

    if (clamp!) {
      to = clampDouble(to, minScrollExtent, maxScrollExtent);
    }

    return super.moveTo(to, duration: duration, curve: curve);
  }

  @override
  bool get allowImplicitScrolling => physics.allowImplicitScrolling;

  // ===========================================

  /// Velocity from a previous activity temporarily held by [hold] to potentially
  /// transfer to a next activity.
  double heldPreviousVelocity = 0.0;

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    final double previousVelocity = activity!.velocity;
    final holdActivity = HoldScrollActivity(
      delegate: this,
      onHoldCanceled: holdCancelCallback,
    );
    beginActivity(holdActivity);
    heldPreviousVelocity = previousVelocity;
    return holdActivity;
  }

  ScrollDragController? _currentDrag;

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    final drag = ScrollDragController(
      delegate: this,
      details: details,
      onDragCanceled: dragCancelCallback,
      carriedVelocity: physics.carriedMomentum(heldPreviousVelocity),
      motionStartDistanceThreshold: physics.dragStartDistanceMotionThreshold,
    );
    beginActivity(DragScrollActivity(this, drag));
    assert(_currentDrag == null);
    _currentDrag = drag;
    return drag;
  }

  @override
  ScrollActivity? get activity => _activity;
  ScrollActivity? _activity;

  @override
  void beginActivity(ScrollActivity? newActivity) {
    heldPreviousVelocity = 0.0;
    if (newActivity == null) {
      return;
    }
    assert(newActivity.delegate == this);
    _beginActivity(newActivity);
    _currentDrag?.dispose();
    _currentDrag = null;
    if (!activity!.isScrolling) {
      updateUserScrollDirection(ScrollDirection.idle);
    }
  }

  void _beginActivity(ScrollActivity? newActivity) {
    if (newActivity == null) {
      return;
    }
    bool wasScrolling, oldIgnorePointer;
    if (_activity != null) {
      oldIgnorePointer = _activity!.shouldIgnorePointer;
      wasScrolling = _activity!.isScrolling;
      if (wasScrolling && !newActivity.isScrolling) {
        // Notifies and then saves the scroll offset.
        didEndScroll();
      }
      _activity!.dispose();
    } else {
      oldIgnorePointer = false;
      wasScrolling = false;
    }
    _activity = newActivity;
    if (oldIgnorePointer != activity!.shouldIgnorePointer) {
      context.setIgnorePointer(activity!.shouldIgnorePointer);
    }
    isScrollingNotifier.value = activity!.isScrolling;
    if (!wasScrolling && _activity!.isScrolling) {
      didStartScroll();
    }
  }

  // NOTIFICATION DISPATCH

  @override
  void didStartScroll() {
    activity!.dispatchScrollStartNotification(
      copyWith(),
      context.notificationContext,
    );
  }

  @override
  void didUpdateScrollPositionBy(double delta) {
    activity!.dispatchScrollUpdateNotification(
      copyWith(),
      context.notificationContext!,
      delta,
    );
  }

  @override
  void didEndScroll() {
    activity!.dispatchScrollEndNotification(
      copyWith(),
      context.notificationContext!,
    );
    saveOffset();
    if (keepScrollOffset) {
      saveScrollOffset();
    }
  }

  @override
  void didOverscrollBy(double value) {
    assert(activity!.isScrolling);
    activity!.dispatchOverscrollNotification(
      copyWith(),
      context.notificationContext!,
      value,
    );
  }

  void updateUserScrollDirection(ScrollDirection value) {
    if (userScrollDirection == value) {
      return;
    }
    _userScrollDirection = value;
    didUpdateScrollDirection(value);
  }

  @override
  void didUpdateScrollDirection(ScrollDirection direction) {
    UserScrollNotification(
      metrics: copyWith(),
      context: context.notificationContext!,
      direction: direction,
    ).dispatch(context.notificationContext);
  }

  @override
  void didUpdateScrollMetrics() {
    assert(
      SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks,
    );
    assert(_haveScheduledUpdateNotification);
    _haveScheduledUpdateNotification = false;
    if (context.notificationContext != null) {
      ScrollMetricsNotification(
        metrics: copyWith(),
        context: context.notificationContext!,
      ).dispatch(context.notificationContext);
    }
  }

  @override
  bool recommendDeferredLoading(BuildContext context) {
    assert(activity != null);
    return physics.recommendDeferredLoading(
      activity!.velocity + _impliedVelocity,
      copyWith(),
      context,
    );
  }

  @override
  void dispose() {
    _currentDrag?.dispose();
    _currentDrag = null;

    activity?.dispose(); // it will be null if it got absorbed by another ScrollPosition
    _activity = null;
    isScrollingNotifier.dispose();
    super.dispose();
  }

  @override
  void applyUserOffset(double delta) {
    updateUserScrollDirection(
      delta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );
    setPixels(pixels - physics.applyPhysicsToUserOffset(this, delta));
  }

  @override
  void goBallistic(double velocity) {
    assert(hasPixels);
    final Simulation? simulation = physics.createBallisticSimulation(
      this,
      velocity,
    );
    if (simulation != null) {
      beginActivity(
        BallisticScrollActivity(
          this,
          simulation,
          context.vsync,
          shouldIgnorePointer,
        ),
      );
    } else {
      goIdle();
    }
  }

  @override
  void goIdle() {
    beginActivity(IdleScrollActivity(this));
  }

  @override
  String? get debugLabel => null;

  @override
  final ValueNotifier<bool> isScrollingNotifier = ValueNotifier<bool>(false);

  @override
  bool get keepScrollOffset => true;
}
