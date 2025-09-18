import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 状态栏管理工具类
class StatusBarUtils {
  // 防止实例化
  StatusBarUtils._();
  
  /// 浅色状态栏
  static void setLightStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // 深色图标
      statusBarBrightness: Brightness.light, // iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  }
  
  /// 深色状态栏
  static void setDarkStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // 浅色图标
      statusBarBrightness: Brightness.dark, // iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  }
  
  /// 自动设置状态栏
  static void setStatusBarForTheme(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      setDarkStatusBar();
    } else {
      setLightStatusBar();
    }
  }
  
  /// 自定义状态栏
  static void setCustomStatusBar({
    Color statusBarColor = Colors.transparent,
    Color navigationBarColor = Colors.transparent,
    Brightness iconBrightness = Brightness.dark,
  }) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: iconBrightness == Brightness.dark 
          ? Brightness.light 
          : Brightness.dark,
      systemNavigationBarColor: navigationBarColor,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  }
  
  /// Edge-to-Edge布局
  static void setEdgeToEdgeLayout() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [],
    );
  }
  
  /// 恢复系统UI
  static void restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }
}
