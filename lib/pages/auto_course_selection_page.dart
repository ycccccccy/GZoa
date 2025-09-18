import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/course_service.dart';
import '../services/auth_service.dart';
import '../utils/status_bar_utils.dart';

class AutoCourseSelectionPage extends StatefulWidget {
  const AutoCourseSelectionPage({super.key});

  @override
  State<AutoCourseSelectionPage> createState() => _AutoCourseSelectionPageState();
}

class _AutoCourseSelectionPageState extends State<AutoCourseSelectionPage> with TickerProviderStateMixin {
  final TextEditingController _courseNameController = TextEditingController();
  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _minuteController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _isSchoolBased = true;
  bool _isRunning = false;
  String _status = '等待设置';
  List<Course> _matchedCourses = [];
  Timer? _timer;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  int _initialCountdownSeconds = 0;
  String? _apiToken;
  String _mainAccountUserName = '';
  
  // 双账号相关
  bool _hasSecondAccount = false;
  String? _secondAccountToken;
  String _secondAccountUserName = '';
  bool _isAddingSecondAccount = false;
  final TextEditingController _secondUserNameController = TextEditingController();
  final TextEditingController _secondPasswordController = TextEditingController();
  
  // 自动抢课相关
  bool _isSearching = false;
  Timer? _courseSearchTimer;
  int _searchAttempts = 0;
  int _emptyResultCount = 0; // 空结果计数
  static const int _maxSearchAttempts = 150; // 30秒，每0.2秒一次
  static const int _emptyResultThreshold = 5; // 5次空结果后调整周期
  static const int _maxEmptyResults = 10; // 10次空结果后终止
  String _bestMatchedCourseId = '';
  double _bestMatchScore = 0.0;
  Duration _currentSearchInterval = const Duration(milliseconds: 200); // 当前搜索间隔
  
  // 双账号抢课状态
  String _account1Status = '';
  String _account2Status = '';
  bool _account1Success = false;
  bool _account2Success = false;

  @override
  void initState() {
    super.initState();
    // 状态栏样式
    StatusBarUtils.setLightStatusBar();
    _loadApiToken();
    // 简化版本：不再从持久化存储加载第二账号
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _secondUserNameController.dispose();
    _secondPasswordController.dispose();
    _timer?.cancel();
    _countdownTimer?.cancel();
    _courseSearchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadApiToken() async {
    final prefs = await SharedPreferences.getInstance();
    _apiToken = prefs.getString('apiToken');
    
    // 加载主账号用户名，优先从新的存储位置获取，如果没有则从旧的位置获取
    _mainAccountUserName = prefs.getString('account1_userName') ?? 
                          prefs.getString('userName') ?? 
                          '主账号';
    
    setState(() {}); // 触发UI更新
  }


  String _getCurrentUserName() {
    return _mainAccountUserName.isNotEmpty ? _mainAccountUserName : '主账号';
  }

  // 使用指定token进行抢课的简化方法
  Future<ApiResult<dynamic>> _bookCourseWithToken(String courseId, String token) async {
    try {
      final String apiUrl = _isSchoolBased 
          ? '${CourseService.baseUrl}/ApiBooking/SetBooking'
          : '${CourseService.baseUrl}/ApiCommunityClass/SetBooking';
      
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final response = await http.post(
        Uri.parse('$apiUrl?t=$timestamp'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'token': token,
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
        body: jsonEncode({
          'More': courseId,
          't': timestamp,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['Success'] == true) {
          return ApiResult.success(responseData['Data']);
        } else {
          return ApiResult.failure(responseData['Message'] ?? '抢课失败');
        }
      } else {
        return ApiResult.failure('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('抢课过程中发生错误: $e');
    }
  }

  // 使用指定token获取我的课程
  Future<ApiResult<List<Course>>> _getMyCoursesWithToken(String token) async {
    try {
      final String apiUrl = _isSchoolBased 
          ? '${CourseService.baseUrl}/ApiBooking/GetCourses'
          : '${CourseService.baseUrl}/ApiCommunityClass/GetCourses';
      
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final response = await http.post(
        Uri.parse('$apiUrl?t=$timestamp'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'token': token,
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['Success'] == true && responseData['Data'] != null) {
          final List<dynamic> coursesData = responseData['Data'];
          final courses = coursesData.map((json) => Course.fromJson(json)).toList();
          return ApiResult.success(courses);
        } else {
          return ApiResult.failure(responseData['Message'] ?? '获取课程失败');
        }
      } else {
        return ApiResult.failure('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('获取课程过程中发生错误: $e');
    }
  }

  Future<void> _loginSecondAccount() async {
    if (_secondUserNameController.text.trim().isEmpty || 
        _secondPasswordController.text.trim().isEmpty) {
      _showMessage('请输入完整的学号和密码');
      return;
    }

    try {
      // 直接调用登录API，不使用复杂的存储逻辑，只临时保存token
      final result = await AuthService.login(
        _secondUserNameController.text.trim(),
        _secondPasswordController.text.trim(),
      );

      if (result.isSuccess && result.apiToken != null) {
        setState(() {
          _hasSecondAccount = true;
          _secondAccountToken = result.apiToken!; // 临时存储token
          _secondAccountUserName = result.userName ?? _secondUserNameController.text.trim(); // 优先使用服务器返回的用户名
          _isAddingSecondAccount = false;
          _secondUserNameController.clear();
          _secondPasswordController.clear();
        });
        _showMessage('第二个账号登录成功');
      } else {
        _showMessage('第二个账号登录失败: ${result.message}');
      }
    } catch (e) {
      _showMessage('登录过程中发生错误: $e');
    }
  }

  Future<void> _removeSecondAccount() async {
    // 简化版本：只清空本地状态，不涉及持久化存储
    setState(() {
      _hasSecondAccount = false;
      _secondAccountToken = null;
      _secondAccountUserName = '';
    });
    _showMessage('已移除第二个账号');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '自动抢课',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontFamily: 'HarmonyOS_SansSC',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型选择
            _buildCourseTypeSelector(),
            const SizedBox(height: 24),
            
            // 双账号管理
            _buildAccountManagement(),
            const SizedBox(height: 24),
            
            // 名称输入
            _buildCourseNameInput(),
            const SizedBox(height: 24),
            
            // 抢课时间选择
            _buildTimeSelector(),
            const SizedBox(height: 24),
            
            // 状态显示
            if (_hasSecondAccount) 
              _buildDualAccountStatusCard()
            else
              _buildStatusCard(),
            const SizedBox(height: 24),
            
            // 匹配的课程列表
            if (_matchedCourses.isNotEmpty) ...[
              _buildMatchedCoursesList(),
              const SizedBox(height: 24),
            ],
            
            // 控制按钮
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseTypeSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '课程类型',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTypeOption(
                    '校本课程',
                    Icons.school,
                    const Color(0xFF007AFF),
                    _isSchoolBased,
                    () => setState(() => _isSchoolBased = true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTypeOption(
                    '社团课程',
                    Icons.groups,
                    const Color(0xFF34C759),
                    !_isSchoolBased,
                    () => setState(() => _isSchoolBased = false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String title, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountManagement() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '账号管理',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!_hasSecondAccount && !_isAddingSecondAccount)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isAddingSecondAccount = true;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('添加第二个账号'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 主账号
            _buildAccountInfo('主账号', _getCurrentUserName(), true),
            
            if (_hasSecondAccount) ...[
              const SizedBox(height: 16),
              _buildAccountInfo('第二账号', _secondAccountUserName, false),
            ],
            
            if (_isAddingSecondAccount) ...[
              const SizedBox(height: 16),
              _buildSecondAccountLogin(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfo(String title, String userName, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF007AFF).withValues(alpha: 0.05) : Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? const Color(0xFF007AFF).withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_circle,
            color: isPrimary ? const Color(0xFF007AFF) : Colors.green,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? const Color(0xFF007AFF) : Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isPrimary)
            IconButton(
              onPressed: _removeSecondAccount,
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: '移除第二个账号',
            ),
        ],
      ),
    );
  }

  Widget _buildSecondAccountLogin() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '添加第二个账号',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _secondUserNameController,
            decoration: InputDecoration(
              labelText: '学号',
              hintText: '请输入第二个账号的学号',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _secondPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入第二个账号的密码',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isAddingSecondAccount = false;
                      _secondUserNameController.clear();
                      _secondPasswordController.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loginSecondAccount,
                  child: const Text('登录'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseNameInput() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '课程名称关键词',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '输入课程名称的关键词，支持多关键词匹配\n例如："摄影" 或 "摄影/心理/编程"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _courseNameController,
              decoration: InputDecoration(
                hintText: '请输入课程名称关键词',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF007AFF)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '抢课时间',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '输入小时和分钟，到达时间后将自动选课',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            
            // 时间输入区域
            Row(
              children: [
                // 小时输入
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '小时',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _hourController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 2,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _HourInputFormatter(),
                        ],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                        decoration: InputDecoration(
                          hintText: '13',
                          counterText: '', // 隐藏字符计数器
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onChanged: (_) => _updateSelectedDateTime(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 分隔符
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 分钟输入
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '分钟',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _minuteController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 2,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _MinuteInputFormatter(),
                        ],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                        decoration: InputDecoration(
                          hintText: '14',
                          counterText: '', // 隐藏字符计数器
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onChanged: (_) => _updateSelectedDateTime(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 当前设定时间显示
            if (_selectedDateTime != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF007AFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFF007AFF).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Color(0xFF007AFF),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '抢课时间已设定',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_isToday(_selectedDateTime!) ? "今天" : "明天"} ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}:00',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimeDescription(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            
            if (_selectedDateTime != null) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDateTime = null;
                      _hourController.clear();
                      _minuteController.clear();
                    });
                  },
                  child: Text(
                    '清除时间',
                    style: TextStyle(
                      color: Colors.red[400],
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDualAccountStatusCard() {
    return Column(
      children: [
        // 第一个账号状态
        _buildAccountStatusCard(
          '主账号 (${_getCurrentUserName()})',
          _account1Status.isEmpty ? _status : _account1Status,
          _account1Success,
          const Color(0xFF007AFF),
        ),
        const SizedBox(height: 16),
        
        // 第二个账号状态
        _buildAccountStatusCard(
          '第二账号 ($_secondAccountUserName)',
          _account2Status.isEmpty ? _status : _account2Status,
          _account2Success,
          Colors.green,
        ),
        
        // 倒计时
        if (_remainingSeconds > 0) ...[
          const SizedBox(height: 20),
          _buildCountdownDisplay(),
        ],
      ],
    );
  }

  Widget _buildAccountStatusCard(String title, String status, bool isSuccess, Color color) {
    final isError = status.contains('失败') || status.contains('错误') || status.contains('出错');
    final isWarning = status.contains('待确认') || status.contains('无法确认');
    
    Color statusColor;
    IconData statusIcon;
    
    if (isSuccess) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isError) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (isWarning) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else if (_isRunning) {
      statusColor = color;
      statusIcon = Icons.play_circle;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.pause_circle;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSuccess 
          ? Colors.green.withValues(alpha: 0.05)
          : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuccess 
            ? Colors.green.withValues(alpha: 0.4)
            : color.withValues(alpha: 0.2),
          width: isSuccess ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSuccess ? Colors.green.withValues(alpha: 0.2) : Colors.transparent,
            blurRadius: isSuccess ? 12 : 0,
            offset: Offset(0, isSuccess ? 4 : 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                statusIcon,
                color: statusColor,
                size: isSuccess ? 24 : 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFamily: 'HarmonyOS_SansSC',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status,
            style: TextStyle(
              fontSize: isSuccess ? 14 : 13,
              fontWeight: isSuccess ? FontWeight.w500 : FontWeight.normal,
              color: isSuccess ? Colors.green[700] : Colors.grey[700],
              fontFamily: 'HarmonyOS_SansSC',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    // 判断状态类型
    final isSuccess = _status.contains('报名成功') || _status.contains('报名确认成功');
    final isError = _status.contains('失败') || _status.contains('错误') || _status.contains('出错');
    final isWarning = _status.contains('待确认') || _status.contains('无法确认');
    
    Color statusColor;
    IconData statusIcon;
    
    if (isSuccess) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isError) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (isWarning) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else if (_isRunning) {
      statusColor = Colors.blue;
      statusIcon = Icons.play_circle;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.pause_circle;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSuccess 
          ? Colors.green.withValues(alpha: 0.05)
          : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuccess 
            ? Colors.green.withValues(alpha: 0.4)
            : Colors.grey.withValues(alpha: 0.2),
          width: isSuccess ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSuccess ? Colors.green.withValues(alpha: 0.2) : Colors.transparent,
            blurRadius: isSuccess ? 12 : 0,
            offset: Offset(0, isSuccess ? 4 : 0),
          ),
        ],
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: isSuccess ? (0.8 + 0.4 * value) : 1.0,
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: isSuccess ? 28 : 20,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
              '状态信息',
              style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'HarmonyOS_SansSC',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * 10),
                child: Opacity(
                  opacity: value,
                  child: Text(
                    _status,
                    style: TextStyle(
                      fontSize: isSuccess ? 16 : 14,
                      fontWeight: isSuccess ? FontWeight.w600 : FontWeight.normal,
                      color: isSuccess ? Colors.green[700] : Colors.grey[700],
                      fontFamily: 'HarmonyOS_SansSC',
                    ),
                  ),
                ),
              );
            },
          ),
          // 成功状态的额外动画效果
          if (isSuccess) ...[
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withValues(alpha: 0.1),
                          Colors.green.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.celebration,
                          color: Colors.green[600],
                          size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                            '恭喜！抢课成功',
                    style: TextStyle(
                      fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                              fontFamily: 'HarmonyOS_SansSC',
                    ),
                  ),
                ),
              ],
            ),
                  ),
                );
              },
            ),
          ],
            if (_remainingSeconds > 0) ...[
              const SizedBox(height: 20),
              _buildCountdownDisplay(),
            ],
          ],
      ),
    );
  }

  Widget _buildCountdownDisplay() {
    final hours = _remainingSeconds ~/ 3600;
    final minutes = (_remainingSeconds % 3600) ~/ 60;
    final seconds = _remainingSeconds % 60;

    // 判断是否小于1分钟
    final isUrgent = _remainingSeconds < 60;
    final isVeryUrgent = _remainingSeconds < 10;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isUrgent 
          ? (isVeryUrgent ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1))
          : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent 
            ? (isVeryUrgent ? Colors.red : Colors.orange)
            : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            '倒计时',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontFamily: 'HarmonyOS_SansSC',
            ),
          ),
          const SizedBox(height: 16),
          // 当小于1分钟时，使用更大的显示
          if (isUrgent) ...[
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isVeryUrgent ? 48 : 40,
                fontWeight: FontWeight.bold,
                color: isVeryUrgent ? Colors.red : Colors.orange,
                fontFamily: 'HarmonyOS_SansSC',
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 100),
                scale: isVeryUrgent && seconds % 2 == 0 ? 1.05 : 1.0, // 闪烁效果
                child: Text(
                  '${seconds.toString().padLeft(2, '0')}',
                ),
              ),
            ),
            const SizedBox(height: 8),
              Text(
                '秒',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isUrgent 
                    ? (isVeryUrgent ? Colors.red[600] : Colors.orange[600])
                    : Colors.grey[600],
                  fontFamily: 'HarmonyOS_SansSC',
                ),
              ),
          ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hours > 0) ...[
                _buildTimeUnit(hours.toString().padLeft(2, '0'), '时'),
                _buildTimeSeparator(),
              ],
              _buildTimeUnit(minutes.toString().padLeft(2, '0'), '分'),
              _buildTimeSeparator(),
              _buildTimeUnit(seconds.toString().padLeft(2, '0'), '秒'),
            ],
          ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _selectedDateTime != null 
                  ? math.max(0.0, math.min(1.0, 1.0 - (_remainingSeconds / math.max(1, _getInitialCountdownSeconds()))))
                  : 0.0,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                _remainingSeconds <= 10 
                    ? Colors.red 
                    : _remainingSeconds <= 60 
                        ? Colors.orange 
                        : Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF007AFF),
              fontFamily: 'HarmonyOS_SansSC',
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontFamily: 'HarmonyOS_SansSC',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF007AFF),
          fontFamily: 'HarmonyOS_SansSC',
        ),
      ),
    );
  }

  Widget _buildMatchedCoursesList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '匹配的课程 (${_matchedCourses.length})',
              style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'HarmonyOS_SansSC',
              ),
            ),
            const SizedBox(height: 16),
          ..._matchedCourses.asMap().entries.map((entry) {
            final index = entry.key;
            final course = entry.value;
            return _buildCourseItem(course, index);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCourseItem(Course course, int index) {
    final isHighMatch = index == 0; // 第一个是最高匹配度的课程
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighMatch 
          ? Colors.green.withValues(alpha: 0.05)
          : Colors.grey.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighMatch 
            ? Colors.green.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
            course.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
                    color: isHighMatch ? Colors.green[700] : Colors.black87,
                    fontFamily: 'HarmonyOS_SansSC',
                  ),
                ),
              ),
              if (isHighMatch)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '推荐',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      fontFamily: 'HarmonyOS_SansSC',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (course.teacher != null && course.teacher!.isNotEmpty)
            Text(
              '教师: ${course.teacher}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontFamily: 'HarmonyOS_SansSC',
              ),
            ),
          if (course.location != null && course.location!.isNotEmpty)
            Text(
              '地点: ${course.location}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontFamily: 'HarmonyOS_SansSC',
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
            Text(
                '已报名: ${course.enrolled ?? 0}/${course.capacity ?? 0}',
              style: TextStyle(
                  fontSize: 13,
                  color: (course.enrolled ?? 0) >= (course.capacity ?? 0) ? Colors.red[600] : Colors.grey[600],
                  fontFamily: 'HarmonyOS_SansSC',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (course.enrolled ?? 0) < (course.capacity ?? 0)
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (course.enrolled ?? 0) < (course.capacity ?? 0) ? '可报名' : '已满',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: (course.enrolled ?? 0) < (course.capacity ?? 0) ? Colors.green[700] : Colors.red[700],
                    fontFamily: 'HarmonyOS_SansSC',
                  ),
              ),
            ),
          ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isRunning ? _stopAutoMode : _startAutoMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRunning ? Colors.red : const Color(0xFF007AFF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isRunning ? '停止抢课' : '开始自动抢课',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'HarmonyOS_SansSC',
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _updateSelectedDateTime() {
    final hourText = _hourController.text.trim();
    final minuteText = _minuteController.text.trim();
    
    if (hourText.isEmpty || minuteText.isEmpty) {
      setState(() {
        _selectedDateTime = null;
      });
      return;
    }
    
    final hour = int.tryParse(hourText);
    final minute = int.tryParse(minuteText);
    
    // 验证时间格式
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      setState(() {
        _selectedDateTime = null;
      });
      return;
    }
    
    final now = DateTime.now();
    var targetDateTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    // 如果设定的时间已经过了，自动设为明天
    if (targetDateTime.isBefore(now)) {
      targetDateTime = targetDateTime.add(const Duration(days: 1));
    }
    
    setState(() {
      _selectedDateTime = targetDateTime;
    });
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year && 
           dateTime.month == now.month && 
           dateTime.day == now.day;
  }

  String _getTimeDescription() {
    if (_selectedDateTime == null) return '';
    
    final now = DateTime.now();
    final difference = _selectedDateTime!.difference(now);
    
    // 时间已过
    if (difference.inMilliseconds < -1000) {
      return '抢课时间已过';
    }
    
    // 使用与倒计时相同的计算方式，避免显示差异
    final remainingSeconds = math.max(0, (difference.inMilliseconds / 1000).ceil());
    
    if (remainingSeconds > 86400) {
      final days = remainingSeconds ~/ 86400;
      return '距离抢课还有 $days 天';
    } else if (remainingSeconds > 3600) {
      final hours = remainingSeconds ~/ 3600;
      final minutes = (remainingSeconds % 3600) ~/ 60;
      return '距离抢课还有 $hours 小时 $minutes 分钟';
    } else if (remainingSeconds > 60) {
      final minutes = remainingSeconds ~/ 60;
      return '距离抢课还有 $minutes 分钟';
    } else if (remainingSeconds > 0) {
      return '距离抢课还有 $remainingSeconds 秒';
    } else if (difference.inMilliseconds >= -1000) {
      return '抢课即将开始';
    } else {
      return '抢课时间已过';
    }
  }

  void _startAutoMode() {
    if (_courseNameController.text.trim().isEmpty) {
      _showMessage('请输入课程名称关键词');
      return;
    }

    // 验证时间输入
    final hourText = _hourController.text.trim();
    final minuteText = _minuteController.text.trim();
    
    if (hourText.isEmpty || minuteText.isEmpty) {
      _showMessage('请输入完整的小时和分钟');
      return;
    }
    
    final hour = int.tryParse(hourText);
    final minute = int.tryParse(minuteText);
    
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      _showMessage('请输入正确的时间格式（小时：0-23，分钟：0-59）');
      return;
    }

    if (_selectedDateTime == null) {
      _showMessage('时间设置有误，请重新输入');
      return;
    }

    if (_selectedDateTime!.isBefore(DateTime.now())) {
      _showMessage('抢课时间不能早于当前时间');
      return;
    }

    setState(() {
      _isRunning = true;
      _status = '等待课程发布...';
    });

    // 只启动倒计时，不立即搜索课程
    _startCountdown();
  }

  void _stopAutoMode({bool preserveSuccess = false}) {
    setState(() {
      _isRunning = false;
      _isSearching = false;
      _remainingSeconds = 0;
      _initialCountdownSeconds = 0;
    });

    _timer?.cancel();
    _countdownTimer?.cancel();
    _courseSearchTimer?.cancel();
    
    // 重置状态
    _searchAttempts = 0;
    _emptyResultCount = 0;
    _bestMatchScore = 0.0;
    _bestMatchedCourseId = '';
    _currentSearchInterval = const Duration(milliseconds: 200);
    
    // 成功停止时保留成功状态与提示
    if (!preserveSuccess) {
      _account1Status = '';
      _account2Status = '';
      _account1Success = false;
      _account2Success = false;
    }
  }


  // 处理课程数据并进行匹配
  void _processCourseData(List<dynamic> coursesData) {
    final keywords = _courseNameController.text.trim().toLowerCase().split('/');
    final List<Course> newMatchedCourses = [];
    
    for (final courseData in coursesData) {
      try {
        // 转换为Course对象
        final course = Course(
          id: courseData['CourseId']?.toString() ?? '',
          name: courseData['CourseName']?.toString() ?? '',
          teacher: courseData['TeacherName']?.toString(),
          location: courseData['Address']?.toString(),
          time: courseData['CreateTime']?.toString(),
          enrolled: courseData['Enrolled'] ?? 0,
          capacity: courseData['MaxTypeNum'] ?? 0,
          isAvailable: courseData['IsAvailable'] ?? true,
        );

        // 计算匹配度
        final matchScore = _calculateMatchScore(course.name.toLowerCase(), keywords);
        
        if (matchScore > 0) {
          newMatchedCourses.add(course);
          
          // 最佳匹配
          if (matchScore > _bestMatchScore) {
            _bestMatchScore = matchScore;
            _bestMatchedCourseId = course.id;
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    // 按匹配度排序
    newMatchedCourses.sort((a, b) {
      final scoreA = _calculateMatchScore(a.name.toLowerCase(), keywords);
      final scoreB = _calculateMatchScore(b.name.toLowerCase(), keywords);
      return scoreB.compareTo(scoreA);
    });
    
    setState(() {
      _matchedCourses = newMatchedCourses;
    });
  }

  // 计算课程名称与关键词的匹配度
  double _calculateMatchScore(String courseName, List<String> keywords) {
    double totalScore = 0.0;
    int matchedKeywords = 0;
    
    for (final keyword in keywords) {
      if (keyword.trim().isEmpty) continue;
      
      if (courseName.contains(keyword.trim())) {
        matchedKeywords++;
        // 完全匹配得分更高
        if (courseName == keyword.trim()) {
          totalScore += 100.0;
        } else if (courseName.startsWith(keyword.trim())) {
          totalScore += 80.0;
        } else {
          totalScore += 50.0;
        }
      }
    }
    
    // 匹配的关键词比例也很重要
    final keywordMatchRatio = matchedKeywords / keywords.length;
    return totalScore * keywordMatchRatio;
  }

  int _getInitialCountdownSeconds() {
    return _initialCountdownSeconds > 0 ? _initialCountdownSeconds : 1;
  }

  void _startCountdown() {
    final now = DateTime.now();
    final target = _selectedDateTime!;
    final difference = target.difference(now).inMilliseconds;

    // 如果时间已经过了，不允许开始抢课
    if (difference < -1000) {
      setState(() {
        _status = '选定的时间已过，请重新设置';
      });
      _stopAutoMode();
      return;
    }

    final initialSeconds = math.max(0, (difference / 1000).ceil());
    setState(() {
      _remainingSeconds = initialSeconds;
      _initialCountdownSeconds = initialSeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final currentTime = DateTime.now();
      final remainingMs = target.difference(currentTime).inMilliseconds;
      
      setState(() {
        _remainingSeconds = math.max(0, (remainingMs / 1000).ceil());
      });

      // 精确在目标时间前200毫秒开始搜索课程
      if (remainingMs <= 200 && remainingMs >= 100) {
        timer.cancel();
        setState(() {
          _status = '抢课时间到达！正在启动高频搜索...';
          _remainingSeconds = 0;
          if (_hasSecondAccount) {
            _account1Status = '准备开始搜索课程...';
            _account2Status = '准备开始搜索课程...';
          }
        });
        // 立即开始执行，不等待
        Future.microtask(() => _executeAutoSelection());
      }
    });
  }

  void _executeAutoSelection() async {
    setState(() {
      _status = '正在搜索课程列表...';
      _account1Status = _hasSecondAccount ? '正在搜索课程...' : '';
      _account2Status = _hasSecondAccount ? '正在搜索课程...' : '';
      _account1Success = false;
      _account2Success = false;
    });

    try {
      // 开始持续搜索课程直到找到匹配的课程
      await _searchCoursesForBooking();
    } catch (e) {
      setState(() {
        _status = '抢课过程中发生错误: $e';
        if (_hasSecondAccount) {
          _account1Status = '抢课过程中发生错误: $e';
          _account2Status = '抢课过程中发生错误: $e';
        }
      });
      _showMessage('抢课失败，请重试');
      _stopAutoMode();
    }
  }

  // 搜索课程
  Future<void> _searchCoursesForBooking() async {
    if (_apiToken == null) {
      setState(() {
        _status = '未找到登录信息，请重新登录';
      });
      return;
    }

    _isSearching = true;
    _searchAttempts = 0;
    _emptyResultCount = 0;
    _bestMatchScore = 0.0;
    _bestMatchedCourseId = '';
    _currentSearchInterval = const Duration(milliseconds: 200);
    
    setState(() {
      _status = '开始高频搜索课程... (每0.2秒一次)';
      _matchedCourses.clear();
    });

    // 立即执行第一次搜索
    bool foundCourses = await _performSingleCourseSearch();
    
    if (foundCourses) {
      // 找到课程了，立即尝试抢课
      if (_hasSecondAccount) {
        await _attemptDualAccountBooking(_bestMatchedCourseId);
      } else {
        await _attemptBooking(_bestMatchedCourseId, false);
      }
      return;
    }

    // 如果第一次没找到，开始定时搜索
    _scheduleNextSearch();
  }

  // 调度下一次搜索
  void _scheduleNextSearch() {
    // 在调度前检查是否还在运行状态
    if (!_isRunning || !_isSearching) {
      return;
    }
    
    _courseSearchTimer = Timer(_currentSearchInterval, () async {
      // 在执行前再次检查状态
      if (!_isRunning || !_isSearching || _searchAttempts >= _maxSearchAttempts || _emptyResultCount >= _maxEmptyResults) {
        if (_emptyResultCount >= _maxEmptyResults) {
          setState(() {
            _status = '连续10次未找到课程，任务已终止';
          });
          _showMessage('连续10次未找到课程，任务已终止');
        } else {
          setState(() {
            _status = '搜索超时，未找到匹配的课程';
          });
          _showMessage('搜索超时，未找到匹配的课程');
        }
        _stopAutoMode();
        return;
      }
      
      bool found = await _performSingleCourseSearch();
      if (found) {
        // 立即停止搜索状态，避免后续搜索干扰
        _isSearching = false;
        
        // 找到课程后立即尝试抢课
        if (_hasSecondAccount) {
          await _attemptDualAccountBooking(_bestMatchedCourseId);
        } else {
          await _attemptBooking(_bestMatchedCourseId, false);
        }
      } else {
        // 继续调度下一次搜索
        _scheduleNextSearch();
      }
    });
  }

  // 执行单次课程搜索
  Future<bool> _performSingleCourseSearch() async {
    // 严格检查状态，防止在抢课过程中被调用
    if (!_isRunning || !_isSearching || _searchAttempts >= _maxSearchAttempts) {
      return false;
    }

    _searchAttempts++;
    
    try {
      final String apiUrl = _isSchoolBased 
          ? '${CourseService.baseUrl}/ApiBooking/GetCourseList'
          : '${CourseService.baseUrl}/ApiCommunityClass/GetCourseList';
      
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final response = await http.post(
        Uri.parse('$apiUrl?t=$timestamp'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
        body: jsonEncode({
          'More': '1',
          'page': 1,
          'limit': 50,
          'keywords': null,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['Success'] == true && responseData['Data'] != null) {
          final List<dynamic> courses = responseData['Data'];
          
          if (courses.isNotEmpty) {
            // 找到课程数据了，重置空结果计数
            _emptyResultCount = 0;
            _processCourseData(courses);
            
            // 再次检查状态，确保不会在抢课过程中覆盖状态
            if (_isRunning && _isSearching) {
              setState(() {
                _status = '找到 ${courses.length} 个课程，最高匹配度: ${_bestMatchScore.toStringAsFixed(2)}';
                if (_hasSecondAccount) {
                  _account1Status = '发现课程，准备抢课...';
                  _account2Status = '发现课程，准备抢课...';
                }
              });
            }
            
            if (_matchedCourses.isNotEmpty && _bestMatchedCourseId.isNotEmpty) {
              // 找到匹配的课程，返回true停止搜索
              return true;
            }
          } else {
            // 空结果，增加计数
            _emptyResultCount++;
            _handleEmptyResult();
          }
        } else {
          // API调用失败或无数据，也算空结果
          _emptyResultCount++;
          _handleEmptyResult();
        }
      }

      
    } catch (e) {
      _emptyResultCount++;
      _handleEmptyResult();
      setState(() {
        _status = '搜索出错: $e (尝试 ${_searchAttempts})';
      });
    }
    
    return false; // 没找到课程
  }

  // 处理空结果的逻辑
  void _handleEmptyResult() {
    if (_emptyResultCount == _emptyResultThreshold) {
      // 5次空结果后调整搜索间隔为0.5秒
      _currentSearchInterval = const Duration(milliseconds: 500);
      setState(() {
        _status = '连续5次未找到课程，调整搜索间隔为0.5秒... (第 ${_searchAttempts} 次)';
      });
    } else if (_emptyResultCount < _emptyResultThreshold) {
      setState(() {
        _status = '搜索中... (第 ${_searchAttempts} 次，连续${_emptyResultCount}次空结果)';
      });
    } else {
      setState(() {
        _status = '搜索中... (第 ${_searchAttempts} 次，搜索间隔0.5秒，连续${_emptyResultCount}次空结果)';
      });
    }
  }

  // 双账号同时抢课
  Future<void> _attemptDualAccountBooking(String courseId) async {
    // 获取匹配课程
    final matchedCourse = _matchedCourses.isNotEmpty ? _matchedCourses.first : null;
    final courseName = matchedCourse?.name ?? '未知课程';
    
    setState(() {
      _account1Status = '正在抢课: $courseName';
      _account2Status = '正在抢课: $courseName';
    });

    try {
      // 并发执行两个账号的抢课，设置超时保护
      final futures = [
        _attemptBooking(courseId, false), // 主账号
        _attemptBooking(courseId, true),  // 第二个账号
      ];
      
      // 30秒超时
      await Future.wait(futures).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          setState(() {
            if (_account1Status.contains('正在')) {
              _account1Status = '抢课超时，请重试';
            }
            if (_account2Status.contains('正在')) {
              _account2Status = '抢课超时，请重试';
            }
          });
          throw TimeoutException('抢课操作超时', const Duration(seconds: 30));
        },
      );
      
      // 检查是否停止
      if (_account1Success || _account2Success) {
        _stopAutoMode(preserveSuccess: true);
      } else {
        // 等待一小段时间后再继续搜索
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      setState(() {
        if (!_account1Status.contains('报名成功') && !_account1Status.contains('抢课超时')) {
          _account1Status = '抢课异常: $e';
        }
        if (!_account2Status.contains('报名成功') && !_account2Status.contains('抢课超时')) {
          _account2Status = '抢课异常: $e';
        }
      });
      
      // 如果是超时异常，不停止搜索，继续尝试
      if (e is! TimeoutException) {
        _stopAutoMode();
      }
    }
  }

  // 尝试报名课程，带重试机制
  Future<void> _attemptBooking(String courseId, bool isSecondAccount) async {
    if (!_hasSecondAccount) {
      setState(() {
        _status = '正在尝试报名课程...';
      });
    } else {
      setState(() {
        if (isSecondAccount) {
          _account2Status = '正在尝试报名课程...';
        } else {
          _account1Status = '正在尝试报名课程...';
        }
      });
    }

    int retryCount = 0;
    const maxRetries = 10; // 最多重试10次
    
    while (retryCount < maxRetries) {
    try {
      // 根据账号类型选择合适的token进行抢课
      final token = isSecondAccount ? _secondAccountToken : _apiToken;
      final result = await _bookCourseWithToken(courseId, token!);

      if (result.isSuccess) {
        // 报名成功，进行确认检查
        if (!_hasSecondAccount) {
          final currentTime = DateTime.now();
          final timeString = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}:${currentTime.second.toString().padLeft(2, '0')}';
          final matchedCourse = _matchedCourses.isNotEmpty ? _matchedCourses.first : null;
          final courseName = matchedCourse?.name ?? '课程';
          
          setState(() {
            _status = '$timeString 报名成功: $courseName！正在确认...';
          });
        } else {
          final currentTime = DateTime.now();
          final timeString = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}:${currentTime.second.toString().padLeft(2, '0')}';
          final matchedCourse = _matchedCourses.isNotEmpty ? _matchedCourses.first : null;
          final courseName = matchedCourse?.name ?? '课程';
          
          setState(() {
            if (isSecondAccount) {
              _account2Status = '$timeString 成功抢到: $courseName';
              _account2Success = true;
            } else {
              _account1Status = '$timeString 成功抢到: $courseName';
              _account1Success = true;
            }
          });
        }
        
        // 延迟1秒后确认报名状态
        await Future.delayed(const Duration(seconds: 1));
        await _confirmBookingStatus(isSecondAccount);
        
        // 只有在单账号模式下才立即停止
        if (!_hasSecondAccount) {
          _stopAutoMode();
        }
        return; // 成功后退出
      } else {
        final errorMessage = result.message ?? '未知错误';
        retryCount++;
        
        // 如果是课程不可选或网络问题，进行重试
        if (errorMessage.contains('课程不可选') || errorMessage.contains('不能为空')) {
          if (!_hasSecondAccount) {
            setState(() {
              _status = '课程暂时不可选，正在重试... (第${retryCount}次)';
            });
          } else {
            setState(() {
              if (isSecondAccount) {
                _account2Status = '课程暂时不可选，正在重试... (第${retryCount}次)';
              } else {
                _account1Status = '课程暂时不可选，正在重试... (第${retryCount}次)';
              }
            });
          }
          
          // 第一次重试等待0.2秒，后续等待0.5秒
          if (retryCount == 1) {
            await Future.delayed(const Duration(milliseconds: 200));
          } else {
            await Future.delayed(const Duration(milliseconds: 500));
          }
          continue; // 继续重试
        } else {
          // 其他错误不重试
          if (!_hasSecondAccount) {
            setState(() {
              _status = '报名失败: $errorMessage';
            });
            _showMessage('报名失败: $errorMessage');
          } else {
            setState(() {
              if (isSecondAccount) {
                _account2Status = '报名失败: $errorMessage';
              } else {
                _account1Status = '报名失败: $errorMessage';
              }
            });
          }
          break;
        }
      }
    } catch (e) {
      retryCount++;
      if (!_hasSecondAccount) {
        setState(() {
          _status = '网络异常，正在重试... (第${retryCount}次)';
        });
      } else {
        setState(() {
          if (isSecondAccount) {
            _account2Status = '网络异常，正在重试... (第${retryCount}次)';
          } else {
            _account1Status = '网络异常，正在重试... (第${retryCount}次)';
          }
        });
      }
      
      if (retryCount == 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    }
    
    // 重试次数用完
    if (!_hasSecondAccount) {
      setState(() {
        _status = '报名失败：重试次数已用完';
      });
      _showMessage('报名失败：已重试${maxRetries}次仍未成功');
      _stopAutoMode();
    } else {
      setState(() {
        if (isSecondAccount) {
          _account2Status = '报名失败：重试次数已用完';
        } else {
          _account1Status = '报名失败：重试次数已用完';
        }
      });
    }
  }

  // 确认报名状态
  Future<void> _confirmBookingStatus(bool isSecondAccount) async {
    try {
      // 使用指定token获取已报名课程
      final token = isSecondAccount ? _secondAccountToken : _apiToken;
      final result = await _getMyCoursesWithToken(token!);

      if (result.isSuccess && result.data != null) {
        final myBookings = result.data!;
        
        // 检查报名课程
        final hasBooking = myBookings.any((course) => course.id == _bestMatchedCourseId);
        
        if (hasBooking) {
          if (!_hasSecondAccount) {
            setState(() {
              _status = '报名确认成功！课程已在"我的课程"中';
            });
          } else {
            setState(() {
              if (isSecondAccount) {
                _account2Status = _account2Status.replaceAll('成功抢到:', '确认成功抢到:');
              } else {
                _account1Status = _account1Status.replaceAll('成功抢到:', '确认成功抢到:');
              }
            });
          }
        } else {
          if (!_hasSecondAccount) {
            setState(() {
              _status = '报名状态待确认，请手动检查';
            });
          } else {
            setState(() {
              if (isSecondAccount) {
                _account2Status = '报名状态待确认，请手动检查';
              } else {
                _account1Status = '报名状态待确认，请手动检查';
              }
            });
          }
        }
      }
    } catch (e) {
      if (!_hasSecondAccount) {
        setState(() {
          _status = '无法确认报名状态，请手动检查';
        });
      } else {
        setState(() {
          if (isSecondAccount) {
            _account2Status = '无法确认报名状态，请手动检查';
          } else {
            _account1Status = '无法确认报名状态，请手动检查';
          }
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// 小时输入格式化器
class _HourInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    
    final int? value = int.tryParse(newValue.text);
    if (value == null) return oldValue;
    
    // 限制小时范围 0-23
    if (value > 23) {
      return oldValue;
    }
    
    return newValue;
  }
}

// 分钟输入格式化器
class _MinuteInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    
    final int? value = int.tryParse(newValue.text);
    if (value == null) return oldValue;
    
    // 限制分钟范围 0-59
    if (value > 59) {
      return oldValue;
    }
    
    return newValue;
  }
}