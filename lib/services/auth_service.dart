import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';

class AuthService {
  static String get baseUrl => EnvConfig.instance.baseUrl;
  static String get loginEndpoint => '$baseUrl/ApiStudent/Login';
  
  // 双账号存储键
  static const String account1TokenKey = 'account1_apiToken';
  static const String account1UserNameKey = 'account1_userName';
  static const String account2TokenKey = 'account2_apiToken';
  static const String account2UserNameKey = 'account2_userName';
  static const String hasSecondAccountKey = 'hasSecondAccount';
  
  // 生成随机openId
  static String _generateOpenId() {
    const uuid = Uuid();
    return uuid.v4();
  }

  // 检查网络连接
  static Future<bool> _checkNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('gzoa.szkz.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // 双账号登录 - 为指定账号登录
  static Future<LoginResult> loginForAccount(String userName, String password, {bool isSecondAccount = false}) async {
    final result = await login(userName, password);
    
    if (result.isSuccess) {
      // 保存到对应账号的存储位置
      await _saveAccountCredentials(result.apiToken!, result.userName!, isSecondAccount);
    }
    
    return result;
  }

  // 保存账号凭据
  static Future<void> _saveAccountCredentials(String apiToken, String userName, bool isSecondAccount) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (isSecondAccount) {
      await prefs.setString(account2TokenKey, apiToken);
      await prefs.setString(account2UserNameKey, userName);
      await prefs.setBool(hasSecondAccountKey, true);
    } else {
      await prefs.setString(account1TokenKey, apiToken);
      await prefs.setString(account1UserNameKey, userName);
      // 保持原有的兼容性
      await prefs.setString('apiToken', apiToken);
      await prefs.setString('userName', userName);
      await prefs.setBool('isLoggedIn', true);
    }
  }

  // 获取账号信息
  static Future<AccountInfo?> getAccountInfo(bool isSecondAccount) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (isSecondAccount) {
      final token = prefs.getString(account2TokenKey);
      final userName = prefs.getString(account2UserNameKey);
      
      if (token != null && userName != null) {
        return AccountInfo(apiToken: token, userName: userName);
      }
    } else {
      final token = prefs.getString(account1TokenKey) ?? prefs.getString('apiToken');
      final userName = prefs.getString(account1UserNameKey) ?? prefs.getString('userName');
      
      if (token != null && userName != null) {
        return AccountInfo(apiToken: token, userName: userName);
      }
    }
    
    return null;
  }

  // 检查是否有第二个账号
  static Future<bool> hasSecondAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(hasSecondAccountKey) ?? false;
  }

  // 清除第二个账号
  static Future<void> clearSecondAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(account2TokenKey);
    await prefs.remove(account2UserNameKey);
    await prefs.setBool(hasSecondAccountKey, false);
  }

  // 登录请求
  static Future<LoginResult> login(String userName, String password) async {
    try {
      // 检查网络连接
      final hasNetwork = await _checkNetworkConnection();
      if (!hasNetwork) {
        return LoginResult.failure(
          message: '网络连接失败，请检查网络设置',
        );
      }

      final openId = _generateOpenId();
      
      final requestBody = {
        'userName': userName,
        'password': password,
        'openId': openId,
      };

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final response = await http.post(
        Uri.parse('$loginEndpoint?t=$timestamp'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['Success'] == true) {
          final data = responseData['Data'];
          if (data != null && data is Map<String, dynamic>) {
            return LoginResult.success(
              apiToken: data['ApiToken']?.toString() ?? '',
              userName: data['UserName']?.toString() ?? '',
            );
          } else {
            return LoginResult.failure(
              message: '服务器返回数据格式错误',
            );
          }
        } else {
          return LoginResult.failure(
            message: responseData['Message'] ?? '登录失败',
          );
        }
      } else {
        return LoginResult.failure(
          message: '网络请求失败: ${response.statusCode}',
        );
      }
    } catch (e) {
      return LoginResult.failure(
        message: '登录过程中发生错误: $e',
      );
    }
  }
}

class LoginResult {
  final bool isSuccess;
  final String? apiToken;
  final String? userName;
  final String? message;

  LoginResult._({
    required this.isSuccess,
    this.apiToken,
    this.userName,
    this.message,
  });

  factory LoginResult.success({
    required String apiToken,
    required String userName,
  }) {
    return LoginResult._(
      isSuccess: true,
      apiToken: apiToken,
      userName: userName,
    );
  }

  factory LoginResult.failure({
    required String message,
  }) {
    return LoginResult._(
      isSuccess: false,
      message: message,
    );
  }
}

// 账号信息类
class AccountInfo {
  final String apiToken;
  final String userName;

  AccountInfo({
    required this.apiToken,
    required this.userName,
  });
}
