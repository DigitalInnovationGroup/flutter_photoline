import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photoline/library.dart';

part 'item.dart';

class SnapExampleList extends StatefulWidget {
  const SnapExampleList({super.key});

  @override
  State<SnapExampleList> createState() => _SnapExampleListState();
}

class _SnapExampleListState extends State<SnapExampleList> {
  final List<_Data> _datas = [];

  late final ScrollSnapController _controller = ScrollSnapController(
    snapBuilder: (index, dimensions) {
      final d = _datas.elementAtOrNull(index);
      if (d == null) return null;
      const double gap = 20;
      return lerpDouble(100 + gap, 200 + gap, d.t);
    },
    snapLastMin: true,
    onRefresh: () async {
      await Future.delayed(const Duration(seconds: 2));
    },
    rebuild: rebuild,
  );

  void rebuild() => setState(() {});

  @override
  void initState() {
    for (var i = 0; i < 20; i++) {
      _datas.add(_Data());
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 100, child: Placeholder(color: Colors.red)),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            return ScrollSnap(
              controller: _controller,
              slivers: [
                ScrollSnapRefresh(controller: _controller),
                SliverSnapList(
                  controller: _controller,
                  builder: (context, index) {
                    final k = ValueKey<int>(Object.hash(index, true));
                    return AutomaticKeepAlive(
                      key: k,
                      child: _Item(
                          index: index,
                          data: _datas[index],
                          parent: _controller,
                          key: k),
                    );
                  },
                  childCount: _datas.length,
                )
              ],
            );
          }),
        ),
        const SizedBox(height: 70, child: Placeholder(color: Colors.purple)),
      ],
    );
  }
}
