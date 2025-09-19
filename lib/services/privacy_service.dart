import 'package:shared_preferences/shared_preferences.dart';

class PrivacyService {
  static const String _privacyAcceptedKey = 'privacy_agreement_accepted';
  static const String _privacyVersionKey = 'privacy_agreement_version';
  
  // 当前隐私协议版本
  static const String _currentPrivacyVersion = '1.0';
  
  /// 检查用户是否已同意隐私协议
  static Future<bool> hasAcceptedPrivacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accepted = prefs.getBool(_privacyAcceptedKey) ?? false;
      final version = prefs.getString(_privacyVersionKey) ?? '';
      
      // 检查用户是否同意过，且版本是最新的
      return accepted && version == _currentPrivacyVersion;
    } catch (e) {
      return false;
    }
  }
  
  /// 记录用户同意隐私协议
  static Future<bool> acceptPrivacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_privacyAcceptedKey, true);
      await prefs.setString(_privacyVersionKey, _currentPrivacyVersion);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 撤销隐私协议同意
  static Future<bool> revokePrivacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_privacyAcceptedKey);
      await prefs.remove(_privacyVersionKey);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 获取当前隐私协议版本
  static String get currentVersion => _currentPrivacyVersion;
}
