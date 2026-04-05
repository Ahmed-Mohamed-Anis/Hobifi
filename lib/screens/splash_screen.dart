import 'dart:math';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  /// Called when the splash animation finishes
  final VoidCallback? onComplete;

  const SplashScreen({super.key, this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Background pattern drift
  late AnimationController _patternController;

  // Logo entrance
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // Shimmer on logo
  late AnimationController _shimmerController;

  // Exit animation
  late AnimationController _exitController;
  late Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    // Continuous slow pattern drift
    _patternController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Logo: scale up + fade in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Shimmer loop
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Exit fade
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Wait for first frame to render
    await Future.delayed(const Duration(milliseconds: 500));

    // Logo enters with elastic bounce
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 700));

    // Shimmer starts looping
    _shimmerController.repeat();

    // Hold the branded splash so the user sees it
    await Future.delayed(const Duration(milliseconds: 2200));

    // Fade out
    await _exitController.forward();
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _patternController.dispose();
    _logoController.dispose();
    _shimmerController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitController,
      builder: (context, child) => Opacity(
        opacity: _exitOpacity.value,
        child: child,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Orange gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8942E), // Warm orange
                    Color(0xFFD97B1F), // Deeper orange
                    Color(0xFFCC6E15), // Rich amber
                  ],
                ),
              ),
            ),

            // Animated hobby icons pattern
            AnimatedBuilder(
              animation: _patternController,
              builder: (context, _) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _HobbyPatternPainter(
                  progress: _patternController.value,
                ),
              ),
            ),

            // Center content — logo image
            Center(
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: child,
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        final shimmerProgress = _shimmerController.value;
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: const [
                            Color(0xFFF5EED6),
                            Color(0xFFFFFFFF),
                            Color(0xFFF5EED6),
                          ],
                          stops: [
                            (shimmerProgress - 0.3).clamp(0.0, 1.0),
                            shimmerProgress.clamp(0.0, 1.0),
                            (shimmerProgress + 0.3).clamp(0.0, 1.0),
                          ],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcIn,
                      child: child!,
                    );
                  },
                  child: Image.asset(
                    'assets/images/hobifi_logo.png',
                    width: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Paints a tiled pattern of hobby-related icons with slow drift
class _HobbyPatternPainter extends CustomPainter {
  final double progress;

  _HobbyPatternPainter({required this.progress});

  // Unicode-like icon representations via path drawing
  static const List<IconData> _icons = [
    Icons.music_note_rounded,
    Icons.palette_rounded,
    Icons.sports_basketball_rounded,
    Icons.camera_alt_rounded,
    Icons.restaurant_rounded,
    Icons.headphones_rounded,
    Icons.piano_rounded,
    Icons.auto_stories_rounded,
    Icons.local_cafe_rounded,
    Icons.sports_tennis_rounded,
    Icons.brush_rounded,
    Icons.fitness_center_rounded,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final iconPaint = TextPainter(textDirection: TextDirection.ltr);
    final rng = Random(77);

    final gridSpacingX = 110.0;
    final gridSpacingY = 120.0;
    final driftX = progress * 30;
    final driftY = progress * 20;

    final cols = (size.width / gridSpacingX).ceil() + 2;
    final rows = (size.height / gridSpacingY).ceil() + 2;

    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final idx = (row * cols + col).abs() % _icons.length;
        final icon = _icons[(idx + rng.nextInt(_icons.length)) % _icons.length];

        // Stagger odd rows
        final offsetX = (row.isOdd ? gridSpacingX * 0.5 : 0.0);
        final x = col * gridSpacingX + offsetX + driftX;
        final y = row * gridSpacingY + driftY;

        // Wrap around
        final wrappedX = (x % (size.width + gridSpacingX)) - gridSpacingX * 0.5;
        final wrappedY = (y % (size.height + gridSpacingY)) - gridSpacingY * 0.5;

        // Slight random rotation per icon
        final rotation = (rng.nextDouble() - 0.5) * 0.4;

        canvas.save();
        canvas.translate(wrappedX, wrappedY);
        canvas.rotate(rotation);

        iconPaint.text = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 32 + rng.nextDouble() * 8,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: const Color(0xFFCC7520).withValues(alpha: 0.35),
          ),
        );
        iconPaint.layout();
        iconPaint.paint(canvas, Offset(-iconPaint.width / 2, -iconPaint.height / 2));

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HobbyPatternPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
