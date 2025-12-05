import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';

class AnimatedSettingsConceptScreen extends StatefulWidget {
  const AnimatedSettingsConceptScreen({super.key});

  @override
  State<AnimatedSettingsConceptScreen> createState() => _AnimatedSettingsConceptScreenState();
}

class _AnimatedSettingsConceptScreenState extends State<AnimatedSettingsConceptScreen>
    with TickerProviderStateMixin {
  late AnimationController _gearController;
  late AnimationController _textController;
  late AnimationController _fabController;
  late AnimationController _glowController;

  late Animation<double> _gearRotation;
  late Animation<double> _textAnimation;
  late Animation<double> _fabScale;
  late Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();

    // Gear rotation animation
    _gearController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _gearRotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _gearController, curve: Curves.linear),
    );

    // Text emergence animation
    _textController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _textAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    );

    // FAB scale animation
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fabScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );

    // Glow pulse animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowPulse = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start animations
    Future.delayed(const Duration(milliseconds: 300), () {
      _textController.forward();
      _fabController.forward();
    });
  }

  @override
  void dispose() {
    _gearController.dispose();
    _textController.dispose();
    _fabController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Top section - Animated Gear Icon
            _buildTopSection(),

            // Bottom section - Floating Star Button
            _buildFloatingStarButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Animated Gear Icon with Glow
          AnimatedBuilder(
            animation: _gearRotation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _gearRotation.value,
                child: _buildGearIcon(),
              );
            },
          ),
          const SizedBox(height: 60),
          // Animated Text Paths
          _buildAnimatedTextPaths(),
        ],
      ),
    );
  }

  Widget _buildGearIcon() {
    return AnimatedBuilder(
      animation: _glowPulse,
      builder: (context, child) {
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Radial glow effect
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: _glowPulse.value),
                blurRadius: 30,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: AppTheme.secondaryColor.withValues(alpha: _glowPulse.value * 0.5),
                blurRadius: 40,
                spreadRadius: 15,
              ),
              // Neumorphic shadows
              BoxShadow(
                color: Colors.white,
                blurRadius: 20,
                offset: const Offset(-5, -5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(5, 5),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFFF5F5F5),
                ],
              ),
            ),
            child: Icon(
              Icons.settings,
              size: 50,
              color: AppTheme.primaryColor.withValues(alpha: 0.8),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTextPaths() {
    return AnimatedBuilder(
      animation: _textAnimation,
      builder: (context, child) {
        return SizedBox(
          height: 300,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildCurvedText(
                text: 'Settings',
                angle: -math.pi / 3, // -60 degrees
                progress: _textAnimation.value,
              ),
              _buildCurvedText(
                text: 'Customize',
                angle: 0, // 0 degrees (straight up)
                progress: _textAnimation.value,
              ),
              _buildCurvedText(
                text: 'Preferences',
                angle: math.pi / 3, // 60 degrees
                progress: _textAnimation.value,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurvedText({
    required String text,
    required double angle,
    required double progress,
  }) {
    final double radius = 120 * progress;
    final double x = radius * math.sin(angle);
    final double y = -radius * math.cos(angle);

    final double opacity = math.min(1.0, progress * 1.5);
    final double scale = 0.5 + (progress * 0.5);

    return Positioned(
      left: MediaQuery.of(context).size.width / 2 + x - 50,
      top: 150 + y - 15,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                // Glowing effect
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3 * opacity),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
                // Motion blur effect (simulated with multiple shadows)
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2 * opacity),
                  blurRadius: 10,
                  offset: Offset(x * 0.1, y * 0.1),
                ),
              ],
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  const Color(0xFFE8D5FF), // Pastel purple
                  const Color(0xFFFFD5E8), // Pastel pink
                  const Color(0xFFD5E8FF), // Pastel blue
                ],
              ).createShader(bounds),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingStarButton() {
    return Positioned(
      bottom: 40,
      right: 20,
      child: AnimatedBuilder(
        animation: _fabScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScale.value,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF0F3FF), // Light pastel purple
                    const Color(0xFFE8D5FF), // Slightly darker purple
                  ],
                ),
                boxShadow: [
                  // Neumorphic shadows
                  BoxShadow(
                    color: Colors.white,
                    blurRadius: 15,
                    offset: const Offset(-4, -4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(4, 4),
                  ),
                  // Soft glow
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _buildStarIcons(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStarIcons() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main purple sparkle icon
        Icon(
          Icons.auto_awesome,
          color: AppTheme.primaryColor,
          size: 35,
        ),
        // Small green bolt icon at bottom-right
        Positioned(
          bottom: 8,
          right: 8,
          child: Icon(
            Icons.bolt,
            color: AppTheme.secondaryColor,
            size: 18,
          ),
        ),
      ],
    );
  }
}

