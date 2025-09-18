import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isWeb => kIsWeb;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  static String get platformName {
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    if (isWeb) return 'Web';
    return 'Unknown';
  }

  static String get platformIcon {
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    if (isWeb) return 'Web';
    return 'Unknown';
  }

  // 获取平台特定的导航栏高度
  static double get navigationBarHeight {
    if (isAndroid) return 56.0;
    if (isIOS) return 44.0;
    if (isDesktop) return 48.0;
    return 56.0;
  }

  // 获取平台特定的状态栏高度
  static double get statusBarHeight {
    if (isAndroid) return 24.0;
    if (isIOS) return 44.0;
    if (isDesktop) return 0.0;
    return 24.0;
  }

  // 使用系统默认字体，不再需要自定义字体配置
}
