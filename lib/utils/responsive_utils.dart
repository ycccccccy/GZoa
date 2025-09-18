import 'package:flutter/material.dart';

class ResponsiveUtils {
  // 响应式断点
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  static const double largeDesktopBreakpoint = 1600;

  // 检测屏幕类型
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= largeDesktopBreakpoint;
  }

  // 获取响应式列数
  static int getGridColumns(BuildContext context, {
    int? mobileColumns,
    int? tabletColumns,
    int? desktopColumns,
  }) {
    if (isMobile(context)) {
      return mobileColumns ?? 1;
    } else if (isTablet(context)) {
      return tabletColumns ?? 2;
    } else {
      return desktopColumns ?? 3;
    }
  }

  // 获取响应式内边距
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(20);
    } else {
      return const EdgeInsets.all(24);
    }
  }

  // 获取响应式字体大小
  static double getResponsiveFontSize(BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  // 获取响应式间距
  static double getResponsiveSpacing(BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return desktop;
    }
  }

  // 获取响应式卡片宽度
  static double getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isMobile(context)) {
      return screenWidth - 32; // 减去左右边距
    } else if (isTablet(context)) {
      return (screenWidth - 64) / 2; // 两列布局
    } else {
      return (screenWidth - 96) / 3; // 三列布局
    }
  }

  // 获取响应式导航栏类型
  static NavigationBarType getNavigationBarType(BuildContext context) {
    if (isMobile(context)) {
      return NavigationBarType.bottom;
    } else {
      return NavigationBarType.side;
    }
  }

  // 获取响应式侧边栏宽度
  static double getSidebarWidth(BuildContext context) {
    if (isDesktop(context)) {
      return 280;
    } else if (isTablet(context)) {
      return 240;
    } else {
      return 0; // 移动端不显示侧边栏
    }
  }
}

enum NavigationBarType {
  bottom,
  side,
}
