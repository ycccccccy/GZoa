import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/platform_utils.dart';
import 'utils/status_bar_utils.dart';
import 'pages/login_page.dart';
import 'pages/course_selection_page.dart';
import 'pages/privacy_agreement_page.dart';
import 'services/privacy_service.dart';
import 'config/env_config.dart';

void main() async {
  // 确保Flutter绑定初始化完成
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化环境配置
  await EnvConfig.init();
  
  // 配置沉浸式状态栏和导航栏
  StatusBarUtils.setLightStatusBar();
  StatusBarUtils.setEdgeToEdgeLayout();
  
  // 设置设备方向为竖屏
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 在Web环境下，确保SharedPreferences完全初始化
  await SharedPreferences.getInstance();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '在线选课系统 (${PlatformUtils.platformName})',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'HarmonyOS_SansSC',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007AFF),
          onPrimary: Colors.white,
          secondary: Color(0xFF007AFF),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF1C1C1E),
          onSurfaceVariant: Color(0xFF8E8E93),
          background: Colors.white,
          onBackground: Color(0xFF1C1C1E),
          error: Color(0xFFFF3B30),
          onError: Colors.white,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shadowColor: Color(0x1A000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(25)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            elevation: 0,
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.5,
            fontFamily: 'HarmonyOS_SansSC',
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.5,
            fontFamily: 'HarmonyOS_SansSC',
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.3,
            fontFamily: 'HarmonyOS_SansSC',
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.2,
            fontFamily: 'HarmonyOS_SansSC',
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: Color(0xFF1C1C1E),
            letterSpacing: 0,
            fontFamily: 'HarmonyOS_SansSC',
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Color(0xFF8E8E93),
            letterSpacing: 0,
            fontFamily: 'HarmonyOS_SansSC',
          ),
        ),
        // 确保弹窗等组件也使用HarmonyOS字体
        dialogTheme: const DialogThemeData(
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
            fontFamily: 'HarmonyOS_SansSC',
          ),
          contentTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: Color(0xFF1C1C1E),
            fontFamily: 'HarmonyOS_SansSC',
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          contentTextStyle: TextStyle(
            fontSize: 14,
            fontFamily: 'HarmonyOS_SansSC',
          ),
        ),
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
            fontFamily: 'HarmonyOS_SansSC',
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}


class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _hasAcceptedPrivacy = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAppStatus();
  }

  Future<void> _checkAppStatus() async {
    try {
      // 添加延迟以确保SharedPreferences完全初始化
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 首先检查隐私协议状态
      final hasAcceptedPrivacy = await PrivacyService.hasAcceptedPrivacy();
      
      // 如果用户已同意隐私协议，再检查登录状态
      bool validLogin = false;
      if (hasAcceptedPrivacy) {
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        final apiToken = prefs.getString('apiToken');
        
        // 验证token是否存在，确保登录状态有效
        validLogin = isLoggedIn && apiToken != null && apiToken.isNotEmpty;
      }
      
      setState(() {
        _hasAcceptedPrivacy = hasAcceptedPrivacy;
        _isLoggedIn = validLogin;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasAcceptedPrivacy = false;
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
          ),
        ),
      );
    }

    // 根据状态决定显示哪个页面
    if (!_hasAcceptedPrivacy) {
      return const PrivacyAgreementPage();
    } else if (_isLoggedIn) {
      return const CourseSelectionPage();
    } else {
      return const LoginPage();
    }
  }
}
