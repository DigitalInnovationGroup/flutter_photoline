import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photoline/library.dart';

class SnapKeyboard extends StatefulWidget {
  const SnapKeyboard({super.key});

  @override
  State<SnapKeyboard> createState() => _SnapKeyboardState();
}

class _SnapKeyboardState extends State<SnapKeyboard> {
  late final ScrollSnapController _controller = ScrollSnapController(
    onReload: () async {},
    getState: () => this,
  );

  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          height: 110,
          child: Placeholder(color: Colors.red),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            return ScrollSnap(
              controller: _controller,
              slivers: [
                SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(
                      height: 600,
                      child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            if (kDebugMode) {
                              await SystemChannels.textInput.invokeMethod('TextInput.hide');
                            }
                          },
                          child: const Placeholder()),
                    ),
                    const _Example(),
                    SizedBox(
                      height: 1,
                      child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            if (kDebugMode) {
                              await SystemChannels.textInput.invokeMethod('TextInput.hide');
                            }
                          },
                          child: const Placeholder()),
                    ),
                  ]),
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

class _Example extends StatelessWidget {
  const _Example();

  static const List<String> _kOptions = <String>['aardvark', 'bobcat', 'chameleon'];

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<String>.empty();
        }
        return _kOptions.where((option) {
          return option.contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (selection) {
        debugPrint('You just selected $selection');
      },
    );
  }
}
