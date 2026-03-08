import 'package:flutter/material.dart';
import 'package:photoline_example/keyboard/keyboard.dart';
import 'package:photoline_example/nested_scroll/widget.dart';

import 'package:photoline_example/photoline/photo.dart';
import 'package:photoline_example/photoline/test.dart';
import 'package:photoline_example/snap/snap.dart';
import 'package:photoline_example/widget/scroll.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        //colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, widget) {
        return Material(
          child: MediaQuery.removePadding(
            context: context,
            child: Overlay(
              //key: AppData.overlay,
              initialEntries: [
                OverlayEntry(
                  builder: (context) => widget!,
                ),
              ],
            ),
          ),
        );
      },
      home: Material(
        child: const [
          NestedDemoScreen(),
          PhotolineTestWidget(),
          PhotolinePhotoWidget(),
          SnapExampleList(),
          SnapKeyboard(),
        ][0],
      ),
    );
  }
}
