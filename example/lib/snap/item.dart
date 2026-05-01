part of 'snap.dart';

class _Data {
  double t = 0;
  bool e = false;
}

class _Item extends StatefulWidget {
  const _Item({required this.index, required this.data, required this.parent, super.key});

  final int index;
  final _Data data;
  final ScrollSnapController parent;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> with TickerProviderStateMixin {
  _Data get data => widget.data;

  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..addListener(_cb);

  void _cb() {
    data.t = _a.value;
    widget.parent.rebuild?.call();
  }

  final _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        data.e = !data.e;
        if (data.e) {
          unawaited(_a.forward());
        } else {
          unawaited(_a.reverse());
        }
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            context.findAncestorStateOfType<ScrollableExState>()?.isPointerPrevent = true;
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Stack(
            children: [
              const Placeholder(),
              if (kProfileMode)
                Positioned.fill(
                    child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) => true,
                  child: SingleChildScrollView(
                    controller: _controller,
                    child: const Text(_t),
                  ),
                ))
            ],
          ),
        ),
      ),
    );
  }
}

const _t = '''
Хорошо, пользователь просит написать приглашение для купания в сгущёнке. Сначала нужно понять контекст. Купание в сгущёнке звучит необычно и, возможно, это метафора или креативная идея для мероприятия. Надо уточнить, но так как это приглашение, скорее всего, речь идет о тематической вечеринке или необычном событии.

Сгущёнка ассоциируется с чем-то сладким, ностальгическим, возможно, детством. Нужно передать игривый и заманчивый тон. Важно использовать яркие образы: густая, сладкая, ароматная сгущёнка. Стоит добавить элементы, которые подчеркнут уникальность события.

Нужно придумать заголовок, который привлечет внимание. Например, Сладкое погружение или Незабываемое купание в молочной сладости. Затем описать, что ждет гостей: ванна со сгущёнкой, возможно, дополнительные развлечения, фотосессия, угощения.

Важно учесть практические моменты: указать дату, время, место, dress code (возможно, что-то легкое для стирки или специальная одежда). Также добавить контакты для подтверждения участия.

Проверить, чтобы текст был дружелюбным, веселым, побуждал к действию. Избежать возможных аллергических предупреждений, если мероприятие реальное. Но если это креативное приглашение, возможно, это не нужно.

Может быть, добавить шутку или игру слов, связанную со сладостями. Убедиться, что приглашение не слишком длинное, но достаточно информативное.

Приглашение на Сладкое Погружение

Дорогой(ая) [Имя]!

Представь: бархатная гладь, густой аромат ванили, и ты — в самом центре молочной сладости! 🌟

Приглашаем тебя на уникальное событие — купание в океане сгущённого молока!

Ждём тебя:
📅 [Дата]
⏰ [Время]
📍 [Место]

В программе:
🍯 Главный аттракцион: гигантская ванна, наполненная теплой сгущёнкой (и да, это так вкусно, как звучит!).
📸 Сладкая фотосессия: кадры, от которых у Instagram случится восторженный взрыв!
🎉 Дегустация: топпинги, блинчики и всё, что сделает день ещё слаще.

Дресс-код: белое (или то, что не жалко покрыться золотистыми каплями сладости).

P.S. Аллергия на улыбки и хорошее настроение — единственное противопоказание!

Подтверди участие до [число] и приготовься к незабываемому погружению!
📲 [Контакты для ответа]

Не упусти шанс стать частью этого безумно-вкусного приключения! До встречи в сладкой волне! 🥄💛

P.P.S. Полотенца, душ и море позитива предоставляем мы. Остальное — возьми с собой!
''';
