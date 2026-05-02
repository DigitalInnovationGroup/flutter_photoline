import 'package:flutter/material.dart';
import 'package:photoline/library.dart';
import 'package:photoline_example/nested_scroll/uris.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Demo profile screen — matches the attached mockup
// ─────────────────────────────────────────────────────────────────────────────

class NestedDemoScreen extends StatefulWidget {
  const NestedDemoScreen({super.key});

  @override
  State<NestedDemoScreen> createState() => _NestedDemoScreenState();
}

class _NestedDemoScreenState extends State<NestedDemoScreen> {
  // ── Header / tab controllers ─────────────────────────────────────────────


  final _headerController = ScrollSnapHeaderController();

  Future<void> _onRefresh() async {
    debugPrint('🔄 Pull-to-refresh triggered');
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('✅ Refresh complete');
  }

  late final ScrollSnapController _galleryController = ScrollSnapController(
    headerHolder: _headerController,
    onReload: _onRefresh,
  );

  late final ScrollSnapController _paramsController = ScrollSnapController(
    headerHolder: _headerController,
    onReload: _onRefresh,
  );

  late final ScrollSnapController _reviewsController = ScrollSnapController(
    headerHolder: _headerController,
    onReload: _onRefresh,
  );

  late final List<ScrollSnapController> _controllers = [
    _galleryController,
    _paramsController,
    _reviewsController,
  ];

  late final PageController _pageController;
  int _currentPage = 0;

  ScrollSnapController get _activeController => _controllers[_currentPage];

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _headerController.activeScrollController = _activeController;
    _pageController = PageController();
    _pageController.addListener(() {
      final p = _pageController.page?.round() ?? 0;
      if (p != _currentPage) {
        setState(() => _currentPage = p);
        _headerController.activeScrollController = _activeController;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _galleryController.dispose();
    _paramsController.dispose();
    _reviewsController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ScrollSnapHeader(
      controller: _headerController,
      onRefresh: _activeController.onReload,
      header: _ProfileHeader(
        controller: _headerController,
        currentPage: _currentPage,
        onTabTap: (i) => _pageController.animateToPage(
          i,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      ),
      content: PageView(
        controller: _pageController,
        children: [
          _GalleryPage(controller: _galleryController),
          _ParamsPage(controller: _paramsController),
          _ReviewsPage(controller: _reviewsController),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER — background photo, avatar, name, social icons, tabs
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.controller,
    required this.currentPage,
    required this.onTabTap,
  });

  final ScrollSnapHeaderController controller;
  final int currentPage;
  final ValueChanged<int> onTabTap;

  static const _tabs = ['Галерея', 'Параметры', 'Отзывы'];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.height,
      builder: (context, _) {
        final h = controller.height.value;
        return SizedBox(
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background photo ──
              Positioned.fill(
                bottom: 100,
                child: Image.network(demoUris.first, fit: BoxFit.cover),
              ),

              // ── Gradient overlay ──
              Positioned.fill(
                bottom: 100,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Name / age / socials ──
              Positioned(
                left: 16,
                right: 16,
                bottom: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspace_premium,
                            color: Colors.amber,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Амбассадор',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // name
                    const Row(
                      children: [
                        Text(
                          'Irina Repei',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.verified,
                          color: Colors.greenAccent,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // age + socials
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.pinkAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          '24 года',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const Spacer(),
                        for (final icon in [
                          Icons.camera_alt,
                          Icons.facebook,
                          Icons.music_note,
                          Icons.play_circle_fill,
                        ]) ...[
                          const SizedBox(width: 10),
                          Icon(icon, color: Colors.white, size: 20),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── White card area (bio + tabs) ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Model, actress, blogger and dancer.\nDM for cooperation.',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                      // ── Tabs ──
                      Row(
                        children: List.generate(_tabs.length, (i) {
                          final sel = i == currentPage;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onTabTap(i),
                              child: Container(
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: sel ? Colors.pinkAccent : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _tabs[i],
                                  style: TextStyle(
                                    color: sel ? Colors.pinkAccent : Colors.grey,
                                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Floating action button (top-right pink circle) ──
              Positioned(
                right: 16,
                bottom: 90,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.pinkAccent, Colors.deepPurple],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB: Галерея
// ═══════════════════════════════════════════════════════════════════════════════

class _GalleryPage extends StatelessWidget {
  const _GalleryPage({required this.controller});

  final ScrollSnapController controller;

  @override
  Widget build(BuildContext context) {
    return ScrollSnap(
      controller: controller,
      slivers: [
        // ── Section: Личные фото ──
        _SectionHeader(title: 'Личные фото', onSeeAll: () {}),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _PhotoTile(uri: demoUris[i]),
              childCount: 6,
            ),
          ),
        ),

        // ── Section: Снепы ──
        _SectionHeader(title: 'Снепы', onSeeAll: () {}),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _PhotoTile(uri: demoUris[i + 6]),
              childCount: 6,
            ),
          ),
        ),

        // bottom spacing
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB: Параметры
// ═══════════════════════════════════════════════════════════════════════════════

class _ParamsPage extends StatelessWidget {
  const _ParamsPage({required this.controller});

  final ScrollSnapController controller;

  static const _params = <(String, String)>[
    ('Рост', '170 см'),
    ('Вес', '52 кг'),
    ('Грудь', '2'),
    ('Обувь', '37'),
    ('Глаза', 'Карие'),
    ('Волосы', 'Тёмные'),
    ('Город', 'Москва'),
    ('Опыт', '5 лет'),
  ];

  @override
  Widget build(BuildContext context) {
    return ScrollSnap(
      controller: controller,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
            final (label, value) = _params[i];
            return ListTile(
              title: Text(label, style: const TextStyle(color: Colors.grey)),
              trailing: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          }, childCount: _params.length),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB: Отзывы
// ═══════════════════════════════════════════════════════════════════════════════

class _ReviewsPage extends StatelessWidget {
  const _ReviewsPage({required this.controller});

  final ScrollSnapController controller;

  @override
  Widget build(BuildContext context) {
    return ScrollSnap(
      controller: controller,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('Отзыв ${i + 1}'),
              subtitle: const Text('Отличная модель, рекомендую!'),
            ),
            childCount: 15,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Section header with "Посмотреть все >"
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'Посмотреть все >',
                style: TextStyle(color: Colors.pinkAccent, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded photo tile loaded from network
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade300,
      ),
      child: Image.network(uri, fit: BoxFit.cover),
    );
  }
}
