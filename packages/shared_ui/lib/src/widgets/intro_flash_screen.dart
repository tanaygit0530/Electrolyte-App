import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A rich, animated intro splash/flash screen for the Electrolyte application ecosystem.
/// Displays the appropriate company logo dynamically based on current theme brightness
/// (Light or Dark), with smooth staggered entrance animations, glowing amber accents,
/// and a seamless transition to the main application interface.
class IntroFlashScreen extends StatefulWidget {
  /// The minimum duration for which the flash screen should remain visible.
  final Duration minDisplayDuration;

  /// Optional destination widget to navigate to when the intro flash finishes.
  final Widget? nextScreen;

  /// Optional callback invoked when the splash duration and animations conclude.
  final VoidCallback? onFinished;

  /// Optional brand tagline or subtitle.
  final String? subtitle;

  /// Whether to show the subtle indeterminate progress indicator.
  final bool showProgress;

  /// Custom footer text.
  final String? footerText;

  const IntroFlashScreen({
    super.key,
    this.minDisplayDuration = const Duration(milliseconds: 2300),
    this.nextScreen,
    this.onFinished,
    this.subtitle = 'POWERING RELIABLE SERVICE',
    this.showProgress = true,
    this.footerText = 'Electrolyte Ecosystem • v1.0.0',
  });

  @override
  State<IntroFlashScreen> createState() => _IntroFlashScreenState();
}

class _IntroFlashScreenState extends State<IntroFlashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoFadeAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _contentFadeAnimation;
  late final Animation<double> _pulseAnimation;

  Timer? _transitionTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation (staggered logo entrance & content reveal)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoFadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _contentFadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
    );

    // 2. Continuous subtle breathing pulse for ambient aura & electric badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start entrance animation
    _entranceController.forward();

    // Schedule navigation or completion callback
    _scheduleCompletion();
  }

  void _scheduleCompletion() {
    _transitionTimer = Timer(widget.minDisplayDuration, () {
      if (!mounted || _hasNavigated) return;

      if (widget.onFinished != null) {
        widget.onFinished!();
      } else if (widget.nextScreen != null) {
        _hasNavigated = true;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                widget.nextScreen!,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildLogoImage(bool isDark) {
    final assetPath = isDark
        ? 'assets/images/company_logo_darktheme.png'
        : 'assets/images/company_logo_lighttheme.png';

    // Try loading with package specification first, fallback to app asset or bolt icon
    return Image.asset(
      assetPath,
      package: 'shared_ui',
      width: 280,
      height: 120,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          assetPath,
          width: 280,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, err2, stackTrace2) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.electric_bolt_rounded,
                  size: 48,
                  color: AppTheme.primaryYellow,
                ),
                const SizedBox(width: 12),
                Text(
                  'ELECTROLYTE',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: isDark ? Colors.white : AppTheme.darkBlueBg,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundGradient = isDark
        ? const RadialGradient(
            center: Alignment(0.0, -0.1),
            radius: 1.25,
            colors: [
              Color(0xFF1B2A47), // Elevated dark navy core
              AppTheme.darkBlueBg, // Core dark blue
              Color(0xFF070D18), // Deep midnight edge
            ],
          )
        : const RadialGradient(
            center: Alignment(0.0, -0.1),
            radius: 1.25,
            colors: [
              Colors.white,
              Color(0xFFF8FAFC),
              Color(0xFFEDF2F7),
            ],
          );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Animated Center Logo Hero Stack
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _entranceController,
                    _pulseController,
                  ]),
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft Ambient Aura Glow
                        Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.primaryYellow.withValues(
                                    alpha: isDark ? 0.22 : 0.14,
                                  ),
                                  AppTheme.primaryYellow.withValues(
                                    alpha: 0.0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Logo Entrance & Scale
                        FadeTransition(
                          opacity: _logoFadeAnimation,
                          child: ScaleTransition(
                            scale: _logoScaleAnimation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: _buildLogoImage(isDark),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Staggered Subtitle, Tagline Badge & Progress Bar
              FadeTransition(
                opacity: _contentFadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                      // Tagline Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppTheme.primaryYellow.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              color: AppTheme.primaryYellow,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                                color: isDark
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Modern Indeterminate Progress Bar
                    if (widget.showProgress)
                      SizedBox(
                        width: 130,
                        height: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryYellow,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Bottom Footer Version Label
              if (widget.footerText != null && widget.footerText!.isNotEmpty)
                FadeTransition(
                  opacity: _contentFadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      widget.footerText!,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.38)
                            : Colors.black.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
