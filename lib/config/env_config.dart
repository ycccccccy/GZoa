import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // 私有构造函数
  EnvConfig._();
  
  // 单例实例
  static final EnvConfig _instance = EnvConfig._();
  static EnvConfig get instance => _instance;
  
  // 初始化环境配置
  static Future<void> init() async {
    await dotenv.load(fileName: ".env");
  }
  
  // 获取是否使用本地服务器
  bool get useLocalServer {
    final value = dotenv.env['USE_LOCAL_SERVER'] ?? 'true';
    return value.toLowerCase() == 'true';
  }
  
  // 获取本地服务器地址
  String get localBaseUrl {
    return dotenv.env['LOCAL_BASE_URL'] ?? 'http://localhost:5000/api';
  }
  
  // 获取远程服务器地址
  String get remoteBaseUrl {
    return dotenv.env['REMOTE_BASE_URL'] ?? '';
  }
  
  // 获取当前使用的基础URL
  String get baseUrl {
    if (useLocalServer) {
      return localBaseUrl;
    }
    return remoteBaseUrl;
  }
  
  // 验证配置是否完整
  bool get isValid {
    if (useLocalServer) {
      return localBaseUrl.isNotEmpty;
    }
    return remoteBaseUrl.isNotEmpty;
  }
}
