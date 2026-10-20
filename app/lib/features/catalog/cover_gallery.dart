import 'package:flutter/material.dart';

import '../../core/widgets/generated_cover.dart';

/// Cabecera del detalle del restaurante: una galería deslizable de fotos con
/// puntos y contador. Con una sola foto (o ninguna) se ve como la portada de siempre.
/// Tocar una foto la abre a pantalla completa con zoom.
class CoverGallery extends StatefulWidget {
  const CoverGallery({super.key, required this.category, required this.seed, required this.images});

  final String category;
  final int seed;

  /// URLs o rutas de assets; la primera es la portada.
  final List<String> images;

  @override
  State<CoverGallery> createState() => _CoverGalleryState();
}

class _CoverGalleryState extends State<CoverGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // En el navegador raíz para tapar también la barra de navegación inferior.
  void _openViewer() => Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _PhotoViewer(images: widget.images, initialPage: _page),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    Widget cover(String? url) => GeneratedCover(category: widget.category, iconSize: 56, seed: widget.seed, imageUrl: url);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (images.length <= 1)
          GestureDetector(
            onTap: images.isEmpty ? null : _openViewer,
            child: cover(images.firstOrNull),
          )
        else
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (_, i) => GestureDetector(onTap: _openViewer, child: cover(images[i])),
          ),
        // Velo arriba para que el título y la flecha se lean sobre fotos claras.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0x55000000)],
                stops: [0, 0.38, 0.7, 1],
              ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: IgnorePointer(child: _Dots(count: images.length, active: _page)),
          ),
          Positioned(
            right: 14,
            bottom: 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      '${_page + 1}/${images.length}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: i == active ? 1 : 0.55),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
    ],
  );
}

/// Visor a pantalla completa: deslizar entre fotos y pellizcar para hacer zoom.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.images, required this.initialPage});

  final List<String> images;
  final int initialPage;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
      title: widget.images.length > 1 ? Text('${_page + 1} de ${widget.images.length}') : null,
    ),
    extendBodyBehindAppBar: true,
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.images.length,
      onPageChanged: (page) => setState(() => _page = page),
      itemBuilder: (_, i) {
        final url = widget.images[i];
        return InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image(
              image: url.startsWith('assets/') ? AssetImage(url) : NetworkImage(url) as ImageProvider,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        );
      },
    ),
  );
}
