import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photoline/library.dart';
import 'package:photoline_example/generated/assets.gen.dart';
import 'package:photoline_example/photoline/controller.dart';
import 'package:photoline_example/photoline/dummy.dart';

part '_child.dart';

part '_photoline.dart';

final List<Widget> dummys = [
  Assets.svg.v2.carousel.dummy0.svg(),
  Assets.svg.v2.carousel.dummy1.svg(),
  Assets.svg.v2.carousel.dummy2.svg(),
];

class PhotolineTestWidget extends StatefulWidget {
  const PhotolineTestWidget({super.key});

  @override
  State<PhotolineTestWidget> createState() => _PhotolineTestWidgetState();
}

double _wrapHeight(double w, double h, double t) {
  const double footer = 64;
  return ui.lerpDouble(w * .7 + footer, h, t)! + 20;
}


class _PhotolineTestWidgetState extends State<PhotolineTestWidget> {
  final List<PhotolineWrap> _photolines = [];
  int _start = -1;

  void rebuild() {
    setState(() {});
  }

  void _reload() {
    _start++;
    while (_photolines.isNotEmpty) {
      _photolines.removeLast().dispose();
    }

    for (int i = _start; i < 50; i++) {
      final photos = PhotolineDummys.list(i);

      _photolines.add(PhotolineWrap(
        photos: photos,
      ));
    }
  }

  @override
  void initState() {
    _reload();
    super.initState();
  }

  late final ScrollSnapController _snap = ScrollSnapController(
    snapLastMax: true,
    snapGap: 20,
    snapArea: true,
    onRefresh: () async {
      await Future.delayed(const Duration(milliseconds: 500));
    },
    snapCan: (index, dimensions) {
      final p = _photolines.elementAtOrNull(index);
      if (p == null) return null;
      final w = dimensions.crossAxisExtent;
      final h = dimensions.viewportMainAxisExtent;

      if (_wrapHeight(w, h, 0) - 20 > h) return false;
      if (_wrapHeight(w, h, 1) - 20 > h) return false;

      return true;
    },
    snapBuilder: (index, dimensions) {
      final p = _photolines.elementAtOrNull(index);
      if (p == null) return null;
      return _wrapHeight(
        dimensions.crossAxisExtent,
        dimensions.viewportMainAxisExtent,
        p.fullScreenExpander.value,
      );
    },
  );

  late final PhotolineHolderDragController _photolineHolderDragController = PhotolineHolderDragController(
    snapController: _snap,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          height: 60,
          child: Placeholder(
            color: Colors.green,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: 600,
              child: PhotolineHolder(
                dragController: _photolineHolderDragController,
                child: ScrollSnap(
                  controller: _snap,
                  cacheExtent: .1,
                  builder: (rebuilder) => [
                    SliverSnapList(
                      controller: _snap,
                      builder: (context, index) => _Child(
                        key: ValueKey(Object.hash(_start, index)),
                        controller: _photolines[index],
                        index: index,
                        constraints: constraints,
                        rebuilder: rebuilder,
                      ),
                      childCount: _photolines.length,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(
          height: 60,
          child: Placeholder(
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}
