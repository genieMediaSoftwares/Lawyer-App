import 'package:flutter/material.dart';

import 'user_avatar.dart';

/// Fullscreen profile picture, the way a messaging app shows one.
///
/// Opened by tapping an avatar. Dark ground, the picture at its own aspect
/// ratio, pinch and double-tap zoom, and the person's name along the bottom.
///
/// The image is loaded from the same resolved URL the avatar was already
/// showing, so opening this costs no second download — Flutter's image cache
/// is keyed on that URL and the avatar has already populated it. That is also
/// why a replaced picture appears immediately: the upload writes a new stored
/// filename, so the URL changes and the old cache entry is simply never asked
/// for again.
class ProfileImageViewer extends StatefulWidget {
  const ProfileImageViewer({
    super.key,
    required this.imagePath,
    this.name,
    this.subtitle,
    this.heroTag,
  });

  /// The raw stored value, resolved by [UserAvatar.resolve] exactly as the
  /// avatar does — so the viewer can never disagree with the thumbnail about
  /// which URL is correct.
  final String? imagePath;

  final String? name;

  /// Role or profession, shown under the name when there is one.
  final String? subtitle;

  /// Shared with the avatar that opened this, to animate between them.
  ///
  /// Null disables the animation, which is the correct choice when the same
  /// person's avatar appears more than once on the screen behind: two widgets
  /// sharing a tag is a Flutter runtime exception, and a missing animation is
  /// a great deal better than a crash. See [UserAvatar.heroTag].
  final Object? heroTag;

  /// Opens the viewer over the current route.
  static Future<void> open(
    BuildContext context, {
    required String? imagePath,
    String? name,
    String? subtitle,
    Object? heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        // Long enough for the hero to read as movement rather than a cut.
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondary) => FadeTransition(
          opacity: animation,
          child: ProfileImageViewer(
            imagePath: imagePath,
            name: name,
            subtitle: subtitle,
            heroTag: heroTag,
          ),
        ),
      ),
    );
  }

  @override
  State<ProfileImageViewer> createState() => _ProfileImageViewerState();
}

class _ProfileImageViewerState extends State<ProfileImageViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();

  /// Drives the double-tap zoom so it eases rather than snapping.
  late final AnimationController _zoomController;
  Animation<Matrix4>? _zoomAnimation;

  /// Where the last double-tap landed, so the zoom centres on it.
  TapDownDetails? _doubleTapAt;

  bool _failed = false;

  static const double _zoomedScale = 2.5;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final value = _zoomAnimation?.value;
        if (value != null) _transform.value = value;
      });
  }

  @override
  void dispose() {
    // Both own native resources; leaking them is what makes a gallery screen
    // get heavier every time it is opened.
    _zoomController.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final isZoomed = _transform.value.getMaxScaleOnAxis() > 1.01;

    final Matrix4 target;
    if (isZoomed) {
      target = Matrix4.identity();
    } else {
      final position = _doubleTapAt?.localPosition;
      if (position == null) {
        target = Matrix4.identity()..scaleByDouble(
          _zoomedScale, _zoomedScale, _zoomedScale, 1,
        );
      } else {
        // Scale about the tapped point rather than the centre, so zooming in
        // on a face keeps that face under the finger.
        target = Matrix4.identity()
          ..translateByDouble(
            -position.dx * (_zoomedScale - 1),
            -position.dy * (_zoomedScale - 1),
            0,
            1,
          )
          ..scaleByDouble(_zoomedScale, _zoomedScale, _zoomedScale, 1);
      }
    }

    _zoomAnimation = Matrix4Tween(begin: _transform.value, end: target)
        .animate(CurvedAnimation(parent: _zoomController, curve: Curves.easeOut));
    _zoomController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final url = UserAvatar.resolve(widget.imagePath);
    final name = (widget.name ?? '').trim();
    final subtitle = (widget.subtitle ?? '').trim();

    Widget image;
    if (url == null || _failed) {
      image = _EmptyPortrait(
        initials: UserAvatar.initialsFrom(name),
        // Distinguishes "never had a picture" from "the picture would not
        // load", which are different problems for the person looking at it.
        failed: _failed,
        onRetry: _failed ? () => setState(() => _failed = false) : null,
      );
    } else {
      image = Image.network(
        url,
        fit: BoxFit.contain,
        // No cacheWidth: this is the fullscreen view, and downsampling here is
        // exactly what makes a zoomed picture look soft.
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stack) {
          // Scheduled rather than set during build, which would be a setState
          // inside a build phase.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_failed) setState(() => _failed = true);
          });
          return const SizedBox.shrink();
        },
      );
    }

    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      // Android's back gesture and button already pop this route; nothing here
      // intercepts them, which is what keeps the system behaviour intact.
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTapDown: (details) => _doubleTapAt = details,
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 5,
              // Room to pan a zoomed portrait to its edges.
              boundaryMargin: const EdgeInsets.all(80),
              child: Center(child: image),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ),

          if (name.isNotEmpty || subtitle.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Caption(name: name, subtitle: subtitle),
            ),
        ],
      ),
    );
  }
}

/// Name and role along the bottom, over a gradient so white text stays legible
/// against a light photograph.
class _Caption extends StatelessWidget {
  const _Caption({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name.isNotEmpty)
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stands in for a picture that is absent or would not load.
class _EmptyPortrait extends StatelessWidget {
  const _EmptyPortrait({
    required this.initials,
    required this.failed,
    this.onRetry,
  });

  final String? initials;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: (initials != null && initials!.isNotEmpty)
                  ? Text(
                      initials!,
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),
          if (failed) ...[
            const SizedBox(height: 20),
            const Text(
              'This picture could not be loaded.',
              style: TextStyle(color: Colors.white70),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
