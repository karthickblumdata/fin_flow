import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RollingMenuButton extends StatefulWidget {
  const RollingMenuButton({
    super.key,
    this.onTap,
    this.iconSize = 18,
    this.collapsedSize = 64.0,
    this.expandedWidth = 280.0,
    this.expandedHeight = 64.0,
    this.useOverlay = false,
    this.overlayLink,
  });

  final VoidCallback? onTap;
  final double iconSize;
  final double collapsedSize;
  final double expandedWidth;
  final double expandedHeight;
  final bool useOverlay;
  final LayerLink? overlayLink;

  @override
  State<RollingMenuButton> createState() => _RollingMenuButtonState();
}

class _RollingMenuButtonState extends State<RollingMenuButton>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  OverlayEntry? _overlayEntry;
  late AnimationController _controller;
  late AnimationController _overlayEntranceController;
  late Animation<double> _expansionAnimation;
  late Animation<double> _textAnimation;
  late Animation<double> _overlaySlideAnimation;
  late Animation<double> _overlayFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // Expansion animation (width, height, border radius)
    _expansionAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // Text reveal animation (starts slightly after expansion)
    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // Overlay entrance animation
    _overlayEntranceController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _overlaySlideAnimation = Tween<double>(
      begin: -20.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _overlayEntranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    _overlayFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _overlayEntranceController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    _overlayEntranceController.dispose();
    super.dispose();
  }

  void _handleHoverEnter() {
    setState(() => _isHovered = true);
    if (widget.useOverlay && widget.overlayLink != null) {
      _showOverlay();
    } else {
      _controller.forward();
    }
  }

  void _handleHoverExit() {
    if (widget.useOverlay) {
      // Delay hiding to allow mouse to move to overlay
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_isHovered) {
          _hideOverlay();
        }
      });
    } else {
      setState(() => _isHovered = false);
      _controller.reverse();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null || widget.overlayLink == null) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    _controller.forward();
    _overlayEntranceController.forward();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: MouseRegion(
            onExit: (_) {
              // Only hide if mouse exits both button and overlay
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted && !_isHovered) {
                  _hideOverlay();
                }
              });
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _hideOverlay(),
              child: Stack(
                children: [
                  CompositedTransformFollower(
                    link: widget.overlayLink!,
                    showWhenUnlinked: false,
                    offset: const Offset(88, 0),
                    child: AnimatedBuilder(
                      animation: _overlayEntranceController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _overlayFadeAnimation.value,
                          child: Transform.translate(
                            offset: Offset(_overlaySlideAnimation.value, 0),
                            child: MouseRegion(
                              onEnter: (_) => setState(() => _isHovered = true),
                              onExit: (_) {
                                setState(() => _isHovered = false);
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  if (mounted && !_isHovered) {
                                    _hideOverlay();
                                  }
                                });
                              },
                              child: Material(
                                color: Colors.transparent,
                                child: _buildExpandedButton(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _controller.reverse();
    _overlayEntranceController.reverse().then((_) {
      if (mounted) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      // Toggle on tap for mobile
      if (_isHovered) {
        _handleHoverExit();
      } else {
        _handleHoverEnter();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: widget.overlayLink ?? LayerLink(),
      child: MouseRegion(
        onEnter: (_) => _handleHoverEnter(),
        onExit: (_) => _handleHoverExit(),
        child: GestureDetector(
          onTap: _handleTap,
          child: widget.useOverlay
              ? _buildCollapsedButton()
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => _buildExpandedButton(),
                ),
        ),
      ),
    );
  }

  Widget _buildCollapsedButton() {
    return Container(
      width: widget.collapsedSize,
      height: widget.collapsedSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF0F3FF), // Light purple
            const Color(0xFFE8D5FF), // Lavender
            Colors.white.withValues(alpha: 0.95),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            blurRadius: 15,
            offset: const Offset(-4, -4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(4, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: _buildStarClusterIcon(),
      ),
    );
  }

  Widget _buildExpandedButton() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Interpolate values based on expansion animation
        // Reduce width for overlay mode to eliminate extra space
        final double targetWidth = widget.useOverlay
            ? widget.expandedWidth * 0.85  // Reduce by 15% for overlay
            : widget.expandedWidth;
        final double width = _lerp(
          widget.collapsedSize,
          targetWidth,
          _expansionAnimation.value,
        );
        final double height = _lerp(
          widget.collapsedSize,
          widget.expandedHeight,
          _expansionAnimation.value,
        );
        final double borderRadius = _lerp(
          widget.collapsedSize / 2, // Full circle
          widget.expandedHeight / 2, // Pill shape
          _expansionAnimation.value,
        );
        // Different padding for overlay vs inline mode
        final double leftPadding = widget.useOverlay
            ? _lerp(14.0, 18.0, _expansionAnimation.value)
            : _lerp(14.0, 24.0, _expansionAnimation.value);
        final double rightPadding = widget.useOverlay
            ? _lerp(14.0, 0.0, _expansionAnimation.value)
            : _lerp(14.0, 8.0, _expansionAnimation.value);
        // Reduce icon-text spacing for overlay mode
        final double iconTextSpacing = widget.useOverlay
            ? _lerp(0.0, 10.0, _expansionAnimation.value)
            : _lerp(0.0, 18.0, _expansionAnimation.value);
        final double iconScale = _lerp(1.0, 1.05, _expansionAnimation.value);

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF0F3FF), // Light purple
                const Color(0xFFE8D5FF), // Lavender
                Colors.white.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              // Neumorphic light shadow (top-left)
              BoxShadow(
                color: Colors.white,
                blurRadius: 15,
                offset: const Offset(-4, -4),
                spreadRadius: 0,
              ),
              // Neumorphic dark shadow (bottom-right)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(4, 4),
                spreadRadius: 0,
              ),
              // Soft glow
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.2 * _expansionAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              // Motion blur effect during animation
              if (_expansionAnimation.value > 0 && _expansionAnimation.value < 1)
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: Offset(4 * (1 - _expansionAnimation.value), 0),
                ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: leftPadding,
              right: rightPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Star cluster icon
                Transform.scale(
                  scale: iconScale,
                  child: _buildStarClusterIcon(),
                ),
                // Spacer that grows with expansion
                SizedBox(width: iconTextSpacing),
                // Text that fades in and slides
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: widget.useOverlay ? 4.0 : 0.0,
                    ),
                    child: _buildTextContent(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStarClusterIcon() {
    return SizedBox(
      width: widget.iconSize,
      height: widget.iconSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            color: AppTheme.primaryColor,
            size: widget.iconSize,
          ),
          Positioned(
            bottom: 0,
            right: -1,
            child: Icon(
              Icons.bolt,
              color: AppTheme.secondaryColor,
              size: widget.iconSize * 0.52,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent() {
    return AnimatedBuilder(
      animation: _textAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _textAnimation.value,
          child: Transform.translate(
            offset: Offset(-20 * (1 - _textAnimation.value), 0),
            child: _buildText(),
          ),
        );
      },
    );
  }

  Widget _buildText() {
    final TextStyle baseStyle = AppTheme.labelMedium.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.black,
      letterSpacing: 0.5,
      fontSize: 14,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Powered by ', style: baseStyle),
          TextSpan(
            text: 'Blumdata',
            style: baseStyle.copyWith(
              color: AppTheme.accentBlue,
            ),
          ),
        ],
      ),
      maxLines: 1,
      textAlign: TextAlign.left,
    );
  }

  double _lerp(double start, double end, double t) {
    return start + (end - start) * t;
  }
}

