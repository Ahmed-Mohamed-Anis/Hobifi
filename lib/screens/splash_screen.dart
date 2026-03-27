import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Wordmark entrance
  late AnimationController _wordmarkController;
  late Animation<double> _wordmarkSlide;
  late Animation<double> _wordmarkOpacity;

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

    // Wordmark: slide up + fade in
    _wordmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _wordmarkSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _wordmarkController, curve: Curves.easeOutCubic),
    );
    _wordmarkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _wordmarkController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
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

    // Wordmark slides up
    _wordmarkController.forward();
    await Future.delayed(const Duration(milliseconds: 600));

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
    _wordmarkController.dispose();
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

            // Center content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo icon with shimmer
                  AnimatedBuilder(
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
                      child: _buildLogoIcon(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // "Hobifi" wordmark
                  AnimatedBuilder(
                    animation: _wordmarkController,
                    builder: (context, child) => Opacity(
                      opacity: _wordmarkOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _wordmarkSlide.value),
                        child: child,
                      ),
                    ),
                    child: Text(
                      'Hobifi',
                      style: GoogleFonts.poppins(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF5EED6),
                        letterSpacing: -1,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Hobifi logo icon (map marker + sparkle, matching the branding)
  Widget _buildLogoIcon() {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: _HobifiLogoPainter(),
      ),
    );
  }
}

/// Draws the Hobifi logo mark: a stylized map/book icon with a sparkle
class _HobifiLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5EED6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Outer rounded rectangle frame
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.15, h * 0.05, w * 0.7, h * 0.75),
      const Radius.circular(14),
    );
    canvas.drawRRect(outerRect, paint);

    // Center fold line (book spine)
    canvas.drawLine(
      Offset(w * 0.5, h * 0.15),
      Offset(w * 0.5, h * 0.7),
      paint,
    );

    // Left page curve
    final leftPath = Path()
      ..moveTo(w * 0.22, h * 0.2)
      ..quadraticBezierTo(w * 0.36, h * 0.32, w * 0.5, h * 0.2);
    canvas.drawPath(leftPath, paint);

    // Right page curve
    final rightPath = Path()
      ..moveTo(w * 0.5, h * 0.2)
      ..quadraticBezierTo(w * 0.64, h * 0.32, w * 0.78, h * 0.2);
    canvas.drawPath(rightPath, paint);

    // Bottom V (map pin point)
    final vPath = Path()
      ..moveTo(w * 0.3, h * 0.75)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.7, h * 0.75);
    canvas.drawPath(vPath, paint);

    // Sparkle (top right)
    final sparkPaint = Paint()
      ..color = const Color(0xFFF5EED6)
      ..style = PaintingStyle.fill;

    _drawSparkle(canvas, Offset(w * 0.72, h * 0.12), 6, sparkPaint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    // 4-pointed star
    path.moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(center.dx + 2, center.dy - 2, center.dx + radius, center.dy);
    path.quadraticBezierTo(center.dx + 2, center.dy + 2, center.dx, center.dy + radius);
    path.quadraticBezierTo(center.dx - 2, center.dy + 2, center.dx - radius, center.dy);
    path.quadraticBezierTo(center.dx - 2, center.dy - 2, center.dx, center.dy - radius);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
