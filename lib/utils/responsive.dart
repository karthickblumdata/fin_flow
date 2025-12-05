import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  // Breakpoints
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

class Responsive {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.mobile &&
        width < ResponsiveBreakpoints.desktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktop;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  // Responsive padding
  static EdgeInsets getPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 80, vertical: 40);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 60, vertical: 30);
    } else {
      return const EdgeInsets.all(24);
    }
  }

  // Responsive font sizes
  static double getTitleSize(BuildContext context) {
    if (isDesktop(context)) {
      return 42;
    } else if (isTablet(context)) {
      return 36;
    } else {
      return 32;
    }
  }

  static double getSubtitleSize(BuildContext context) {
    if (isDesktop(context)) {
      return 18;
    } else if (isTablet(context)) {
      return 16;
    } else {
      return 14;
    }
  }

  // Responsive icon size
  static double getIconSize(BuildContext context) {
    if (isDesktop(context)) {
      return 100;
    } else if (isTablet(context)) {
      return 90;
    } else {
      return 80;
    }
  }

  // Max width constraint for content
  static double getMaxContentWidth(BuildContext context) {
    if (isDesktop(context)) {
      return 1200;
    } else if (isTablet(context)) {
      return 800;
    } else {
      return double.infinity;
    }
  }

  // Form width for desktop/tablet
  static double getFormWidth(BuildContext context) {
    if (isDesktop(context)) {
      return 480;
    } else if (isTablet(context)) {
      return 500;
    } else {
      return double.infinity;
    }
  }
}

