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

  // 通用分页数据拉取方法 - 支持keywords查询
  static Future<List<Map<String, dynamic>>> _fetchAllPages({
    required String endpoint,
    required Map<String, dynamic> baseParams,
    bool isSecondAccount = false,
  }) async {
    List<Map<String, dynamic>> allData = [];
    int currentPage = 1;
    bool hasMoreData = true;
    int? totalCount;

    while (hasMoreData) {
      try {
        final timestamp = _getTimestamp();
        final headers = await _getHeaders(isSecondAccount: isSecondAccount);
        
        final params = Map<String, dynamic>.from(baseParams);
        params['page'] = currentPage;
        params['limit'] = 10; // 使用真实API的默认分页大小
        
        final response = await http.post(
          Uri.parse('$baseUrl$endpoint?t=$timestamp'),
          headers: headers,
          body: jsonEncode(params),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          // 打印原始响应数据，方便调试
          
          // 兼容两种数据结构
          List<dynamic>? data;
          // 优先解析Data字段，即使Success为false
          if (responseData['Data'] != null && responseData['Data'] is List) {
            // 结构 1: { "Success": true/false, "Data": [...], "Total": ... }
            data = responseData['Data'] as List;
            totalCount = responseData['Total'] as int?;
          } else if (responseData['Item1'] != null && 
                     responseData['Item1']['Data'] != null && 
                     responseData['Item1']['Data'] is List) {
            // 结构 2: { "Item1": { "Data": [...], "Total": ... } }
            final item1 = responseData['Item1'];
            data = item1['Data'] as List;
            totalCount = item1['Total'] as int?;
          }
          
          if (data != null) {
            if (data.isEmpty) {
              // 当前页没有数据，停止分页
              hasMoreData = false;
            } else {
              // 添加当前页数据
              allData.addAll(data.cast<Map<String, dynamic>>());
              
              // 判断是否还有更多数据
              bool shouldContinue = true;
              
              // 方式1: 通过totalCount判断（最准确）
              if (totalCount != null && allData.length >= totalCount) {
                shouldContinue = false;
              }
              // 方式2: 如果当前页数据少于页面大小，说明已到最后一页
              else if (data.length < 10) {
                shouldContinue = false;
              }
              
              if (shouldContinue) {
                currentPage++;
              } else {
                hasMoreData = false;
              }
            }
          } else {
            // API返回失败或没有数据
            hasMoreData = false;
          }
        } else {
          // HTTP请求失败，停止分页
          hasMoreData = false;
        }
      } catch (e) {
        // 出现异常，停止分页
        hasMoreData = false;
      }
    }

    return allData;
  }

  // 获取所有可报名的校本课程
  static Future<ApiResult<List<Course>>> getAllSchoolBasedCourses({bool isSecondAccount = false}) async {
    final courses = await _fetchAllPages(
      endpoint: '/ApiBooking/GetTypeList',
      baseParams: {'keywords': ''},
      isSecondAccount: isSecondAccount,
    );
    return ApiResult.success(courses.map((e) => Course.fromJson(e)).toList());
  }

  // 获取所有可报名的社团课程
  static Future<ApiResult<List<Course>>> getAllCommunityCourses({bool isSecondAccount = false}) async {
    final courses = await _fetchAllPages(
      endpoint: '/ApiCommunityClass/GetTypeList',
      baseParams: {'keywords': ''},
      isSecondAccount: isSecondAccount,
    );
    return ApiResult.success(courses.map((e) => Course.fromJson(e)).toList());
  }

  // 获取已报名的校本课程
  static Future<ApiResult<List<Course>>> getMySchoolBasedCourses({bool isSecondAccount = false}) async {
    // 并行获取已审核和未审核的课程
    final unreviewedCourses = await _fetchAllPages(
      endpoint: '/ApiBooking/GetCourses', 
      baseParams: {'More': 1, 'keywords': ''}, 
      isSecondAccount: isSecondAccount
    );
    final reviewedCourses = await _fetchAllPages(
      endpoint: '/ApiBooking/GetCourses',
      baseParams: {'More': 0, 'keywords': ''},
      isSecondAccount: isSecondAccount
    );
    
    final allCoursesRaw = [...unreviewedCourses, ...reviewedCourses];
      
    // 根据课程ID去重
    final Map<String, Map<String, dynamic>> uniqueCourses = {};
    for (final courseData in allCoursesRaw) {
      final courseId = courseData['CourseId']?.toString() ?? 
                      courseData['courseId']?.toString() ?? 
                      courseData['Id']?.toString() ?? '';
      if (courseId.isNotEmpty) {
        uniqueCourses[courseId] = courseData;
      }
    }
    
    return ApiResult.success(uniqueCourses.values.map((item) => Course.fromJson(item)).toList());
  }

  // 获取社团课程（包括已审核和未审核）
  static Future<ApiResult<List<Course>>> getMyCommunityCourses({bool isSecondAccount = false}) async {
    // 并行获取已审核和未审核的课程
    final unreviewedCourses = await _fetchAllPages(
      endpoint: '/ApiCommunityClass/GetCourses',
      baseParams: {'More': 1, 'keywords': ''},
      isSecondAccount: isSecondAccount
    );
    final reviewedCourses = await _fetchAllPages(
      endpoint: '/ApiCommunityClass/GetCourses',
      baseParams: {'More': 0, 'keywords': ''},
      isSecondAccount: isSecondAccount
    );

    final allCoursesRaw = [...unreviewedCourses, ...reviewedCourses];
      
    // 根据课程ID去重
    final Map<String, Map<String, dynamic>> uniqueCourses = {};
    for (final courseData in allCoursesRaw) {
      final courseId = courseData['CourseId']?.toString() ?? 
                      courseData['courseId']?.toString() ?? 
                      courseData['Id']?.toString() ?? '';
      if (courseId.isNotEmpty) {
        uniqueCourses[courseId] = courseData;
      }
    }
    
    return ApiResult.success(uniqueCourses.values.map((item) => Course.fromJson(item)).toList());
  }

  static Future<ApiResult<Map<String, dynamic>>> bookSchoolBasedCourse(String courseId, {bool isSecondAccount = false}) async {
    return _bookCourse(
      endpoint: '/ApiBooking/SetBooking',
      courseId: courseId,
      isSecondAccount: isSecondAccount
    );
  }

  static Future<ApiResult<Map<String, dynamic>>> bookCommunityCourse(String courseId, {bool isSecondAccount = false}) async {
    return _bookCourse(
      endpoint: '/ApiCommunityClass/SetBooking',
      courseId: courseId,
      isSecondAccount: isSecondAccount
    );
  }

  // 自动抢课专用 - 根据关键词获取相关课程（带完整分页）
  static Future<ApiResult<List<Course>>> getAvailableCoursesForAutoBooking(
    bool isSchoolBased, 
    String keywords,
    {bool isSecondAccount = false}
  ) async {
    final endpoint = isSchoolBased ? '/ApiBooking/GetTypeList' : '/ApiCommunityClass/GetTypeList';
    try {
      final courses = await _fetchAllPages(
        endpoint: endpoint,
        baseParams: {'keywords': keywords},
        isSecondAccount: isSecondAccount,
      );
      return ApiResult.success(courses.map((e) => Course.fromJson(e)).toList());
    } catch (e) {
      return ApiResult.failure('获取可用课程时发生错误: $e');
    }
  }
  
  // 通用预定课程逻辑
  static Future<ApiResult<Map<String, dynamic>>> _bookCourse({
    required String endpoint,
    required String courseId,
    bool isSecondAccount = false,
  }) async {
    try {
      final timestamp = _getTimestamp();
      final headers = await _getHeaders(isSecondAccount: isSecondAccount);
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint?t=$timestamp'),
        headers: headers,
        body: jsonEncode({'More': courseId}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['Success'] == true) {
          // 成功预定
          return ApiResult.success({'message': responseData['Message'] ?? '预定成功'});
        } else {
          return ApiResult.failure(responseData['Message'] ?? '预定失败');
        }
      } else {
        return ApiResult.failure('服务器错误: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('网络错误: $e');
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
    // 优先使用TeacherNot，然后是TeacherName，最后是Teacher，并兼容大小写和空字符串
    String? teacher;
    final dynamic teacherNot = json['TeacherNot'] ?? json['teacherNot'];
    final dynamic teacherName = json['TeacherName'] ?? json['teacherName'];
    final dynamic teacherField = json['Teacher'] ?? json['teacher'];

    if (teacherNot != null && teacherNot.toString().trim().isNotEmpty) {
      teacher = teacherNot.toString();
    } else if (teacherName != null && teacherName.toString().trim().isNotEmpty) {
      teacher = teacherName.toString();
    } else if (teacherField != null && teacherField.toString().trim().isNotEmpty) {
      teacher = teacherField.toString();
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
