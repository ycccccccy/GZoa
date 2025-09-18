import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';

class CourseService {
  // 获取API基础URL
  static String get baseUrl {
    return EnvConfig.instance.baseUrl;
  }
  
  // 获取Token
  static Future<String?> _getApiToken({bool isSecondAccount = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (isSecondAccount) {
      return prefs.getString('account2_apiToken');
    } else {
      return prefs.getString('account1_apiToken') ?? prefs.getString('apiToken');
    }
  }

  // 生成时间戳
  static String _getTimestamp() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // 通用请求头
  static Future<Map<String, String>> _getHeaders({bool isSecondAccount = false}) async {
    final token = await _getApiToken(isSecondAccount: isSecondAccount);
    return {
      'Content-Type': 'application/json;charset=UTF-8',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      if (token != null) 'token': token,
    };
  }

  // 校本课程 - 获取课程类型列表
  static Future<ApiResult<List<CourseType>>> getSchoolBasedCourseTypes() async {
    try {
      final timestamp = _getTimestamp();
      final headers = await _getHeaders();
      final url = '$baseUrl/ApiBooking/GetTypeList?t=$timestamp';
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'page': 1,
          'limit': 100,
          'keywords': '',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['Success'] == true) {
          final data = responseData['Data'] as List;
          final types = data.map((item) => CourseType.fromJson(item)).toList();
          return ApiResult.success(types);
        } else {
          return ApiResult.failure(responseData['Message'] ?? '获取课程类型失败');
        }
      } else {
        return ApiResult.failure('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('获取课程类型时发生错误: $e');
    }
  }

  // 校本课程 - 获取课程列表
  static Future<ApiResult<List<Course>>> getSchoolBasedCourses(String typeId) async {
    try {
      final timestamp = _getTimestamp();
      final response = await http.post(
        Uri.parse('$baseUrl/ApiBooking/GetCourseList?t=$timestamp'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'More': typeId,
          'page': 1,
          'limit': 100,
          'keywords': '',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['Success'] == true) {
          final data = responseData['Data'] as List;
          final courses = data.map((item) => Course.fromJson(item)).toList();
          return ApiResult.success(courses);
        } else {
          return ApiResult.failure(responseData['Message'] ?? '获取课程列表失败');
        }
      } else {
        return ApiResult.failure('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('获取课程列表时发生错误: $e');
    }
  }

  // 校本课程 - 选课确认 (支持双账号)
  static Future<ApiResult<String>> bookSchoolBasedCourse(String courseId, {bool isSecondAccount = false}) async {
    try {
      final timestamp = _getTimestamp();
      final response = await http.post(
        Uri.parse('$baseUrl/ApiBooking/SetBooking?t=$timestamp'),
        headers: await _getHeaders(isSecondAccount: isSecondAccount),
        body: jsonEncode({
          'More': courseId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['Success'] == true) {
          return ApiResult.success('选课成功');
        } else {
          return ApiResult.failure(responseData['Message'] ?? '选课失败');
        }
      } else {
        return ApiResult.failure('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('选课时发生错误: $e');
    }
  }

  // 社团课程 - 获取社团类型列表
  static Future<ApiResult<List<CourseType>>> getCommunityCourseTypes() async {
    try {
      final timestamp = _getTimestamp();
      final headers = await _getHeaders();
      final url = '$baseUrl/ApiCommunityClass/GetTypeList?t=$timestamp';
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'page': 1,
          'limit': 100,
          'keywords': '',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['Success'] == true) {
          final data = responseData['Data'] as List;
          final types = data.map((item) => CourseType.fromJson(item)).toList();
          return ApiResult.success(types);
        } else {
          return ApiResult.failure(responseData['Message'] ?? '获取社团类型失败');
        }
      } else {
        return ApiResult.failure('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('获取社团类型时发生错误: $e');
    }
  }

  // 社团课程 - 获取社团课程列表
  static Future<ApiResult<List<Course>>> getCommunityCourses(String typeId) async {
    try {
      final timestamp = _getTimestamp();
      final response = await http.post(
        Uri.parse('$baseUrl/ApiCommunityClass/GetCourseList?t=$timestamp'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'More': typeId,
          'page': 1,
          'limit': 100,
          'keywords': '',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['Success'] == true) {
          final data = responseData['Data'] as List;
          final courses = data.map((item) => Course.fromJson(item)).toList();
          return ApiResult.success(courses);
        } else {
          return ApiResult.failure(responseData['Message'] ?? '获取社团课程列表失败');
        }
      } else {
        return ApiResult.failure('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('获取社团课程列表时发生错误: $e');
    }
  }

  // 社团课程 - 选课确认 (支持双账号)
  static Future<ApiResult<String>> bookCommunityCourse(String courseId, {bool isSecondAccount = false}) async {
    try {
      final timestamp = _getTimestamp();
      final response = await http.post(
        Uri.parse('$baseUrl/ApiCommunityClass/SetBooking?t=$timestamp'),
        headers: await _getHeaders(isSecondAccount: isSecondAccount),
        body: jsonEncode({
          'More': courseId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['Success'] == true) {
          return ApiResult.success('选课成功');
        } else {
          return ApiResult.failure(responseData['Message'] ?? '选课失败');
        }
      } else {
        return ApiResult.failure('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('选课时发生错误: $e');
    }
  }

  // 获取校本课程
  static Future<ApiResult<List<Course>>> getMySchoolBasedCourses({bool isSecondAccount = false}) async {
    try {
      final timestamp = _getTimestamp();
      final headers = await _getHeaders(isSecondAccount: isSecondAccount);
      final url = '$baseUrl/ApiBooking/GetCourses?t=$timestamp';
      
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'More': 0, // 0表示已审核的课程
          'page': 1,
          'limit': 100,
          'keywords': '',
        }),
      );


      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // 即使Success为false，只要有数据就认为成功
        if (responseData['Data'] != null && responseData['Data'] is List) {
          final data = responseData['Data'] as List;
          if (data.isNotEmpty) {
            final courses = data.map((item) => Course.fromJson(item)).toList();
            return ApiResult.success(courses);
          }
        }
        
        // 如果没有数据，检查Success字段
        if (responseData['Success'] == true) {
          final data = responseData['Data'] as List;
          final courses = data.map((item) => Course.fromJson(item)).toList();
          return ApiResult.success(courses);
        } else {
          return ApiResult.failure(responseData['Message'] ?? '获取已报名课程失败');
        }
      } else {
        return ApiResult.failure('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('获取已报名课程时发生错误: $e');
    }
  }

  // 获取社团课程
  static Future<ApiResult<List<Course>>> getMyCommunityCourses({bool isSecondAccount = false}) async {
    try {
      final timestamp = _getTimestamp();
      final headers = await _getHeaders(isSecondAccount: isSecondAccount);
      final url = '$baseUrl/ApiCommunityClass/GetCourses?t=$timestamp';
      
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'More': 0, // 0表示已审核的课程
          'page': 1,
          'limit': 100,
          'keywords': '',
        }),
      );


      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // 即使Success为false，只要有数据就认为成功
        if (responseData['Data'] != null && responseData['Data'] is List) {
          final data = responseData['Data'] as List;
          if (data.isNotEmpty) {
            final courses = data.map((item) => Course.fromJson(item)).toList();
            return ApiResult.success(courses);
          }
        }
        
        // 如果没有数据，检查Success字段
        if (responseData['Success'] == true) {
          final data = responseData['Data'] as List;
          final courses = data.map((item) => Course.fromJson(item)).toList();
          return ApiResult.success(courses);
        } else {
          return ApiResult.failure(responseData['Message'] ?? '获取已报名课程失败');
        }
      } else {
        return ApiResult.failure('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('获取已报名课程时发生错误: $e');
    }
  }
}

// API结果封装类
class ApiResult<T> {
  final bool isSuccess;
  final T? data;
  final String? message;

  ApiResult._({required this.isSuccess, this.data, this.message});

  factory ApiResult.success(T data) {
    return ApiResult._(isSuccess: true, data: data);
  }

  factory ApiResult.failure(String message) {
    return ApiResult._(isSuccess: false, message: message);
  }
}

// 课程类型
class CourseType {
  final String id;
  final String name;
  final String? description;

  CourseType({
    required this.id,
    required this.name,
    this.description,
  });

  factory CourseType.fromJson(Map<String, dynamic> json) {
    return CourseType(
      id: json['Id']?.toString() ?? '',
      name: json['Name'] ?? '',
      description: json['Description'],
    );
  }
}

// 课程
class Course {
  final String id;
  final String name;
  final String? teacher;
  final String? time;
  final String? location;
  final int? credits;
  final int? capacity;
  final int? enrolled;
  final bool isAvailable;
  final String? description;
  final String? typeName;

  Course({
    required this.id,
    required this.name,
    this.teacher,
    this.time,
    this.location,
    this.credits,
    this.capacity,
    this.enrolled,
    required this.isAvailable,
    this.description,
    this.typeName,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    // TeacherNot是教师名字，TeacherName是负责人，优先使用TeacherNot
    String? teacher;
    if (json['TeacherNot'] != null && json['TeacherNot'].toString().isNotEmpty) {
      teacher = json['TeacherNot'].toString();
    } else if (json['TeacherName'] != null && json['TeacherName'].toString().isNotEmpty) {
      teacher = json['TeacherName'].toString();
    } else {
      teacher = json['Teacher'];
    }
    
    // 兼容字段命名
    final dynamic rawId = json['CourseId'] ?? json['courseId'] ?? json['Id'];
    final String id = rawId?.toString() ?? '';
    final String name = (json['CourseName'] ?? json['courseName'] ?? json['Name'] ?? '').toString();
    final String? time = json['Time']?.toString() ?? json['CreateTime']?.toString();
    final String? location = json['Address']?.toString() ?? json['Location']?.toString();
    final int? credits = (json['Credits'] ?? json['Credit']) as int?;
    final int? capacity = (json['MaxTypeNum'] ?? json['Capacity']) as int?;
    final int? enrolled = (json['Enrolled'] ?? json['Count']) as int?;

    // 缺省为true，若有上限/人数则进行可选判断
    final bool isAvailable = (json['IsAvailable'] ?? true) == true &&
        (json['MaxTypeNum'] == null || json['Count'] == null ||
            (json['Count'] as int? ?? 0) < (json['MaxTypeNum'] as int? ?? 1 << 30));

    return Course(
      id: id,
      name: name,
      teacher: teacher,
      time: time,
      location: location,
      credits: credits,
      capacity: capacity,
      enrolled: enrolled,
      isAvailable: isAvailable,
      description: json['Description'] ?? json['Title'],
      typeName: json['TypeName'] ?? json['Title'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Course && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
