import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/responsive_utils.dart';
import '../utils/status_bar_utils.dart';
import '../services/course_service.dart';
import '../widgets/shimmer_widgets.dart';
import '../widgets/animated_widgets.dart';
import 'course_detail_page.dart';
import 'auto_course_selection_page.dart';
import 'login_page.dart';

class CourseSelectionPage extends StatefulWidget {
  const CourseSelectionPage({super.key});

  @override
  State<CourseSelectionPage> createState() => _CourseSelectionPageState();
}

class _CourseSelectionPageState extends State<CourseSelectionPage> {
  String _userName = '';
  bool _isLoading = true;
  List<CourseType> _schoolTypes = [];
  List<CourseType> _communityTypes = [];
  List<Course> _courses = [];
  List<Course> _mySchoolCourses = [];
  List<Course> _myCommunityCourses = [];
  
  // 当前页面状态
  CoursePageState _currentState = CoursePageState.selectType;
  
  // 当前显示的课程类型
  String? _currentCourseType;
  bool _isSchoolBased = true;
  
  @override
  void initState() {
    super.initState();
    // 浅色状态栏
    StatusBarUtils.setLightStatusBar();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 先加载用户信息
      await _loadUserInfo();
      // 然后加载课程类型
      await _loadCourseTypes();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('应用初始化失败，请刷新页面重试');
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('userName') ?? '';
      setState(() {
        _userName = userName;
      });
    } catch (e) {
      // 静默处理用户信息加载失败
    }
  }

  Future<void> _loadCourseTypes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 添加重试机制，最多重试3次
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          // 并行加载校本课程和社团课程类型，以及已报名课程
          final schoolResult = await CourseService.getSchoolBasedCourseTypes();
          final communityResult = await CourseService.getCommunityCourseTypes();
          final mySchoolResult = await CourseService.getMySchoolBasedCourses();
          final myCommunityResult = await CourseService.getMyCommunityCourses();

          // 调试信息

          setState(() {
            if (schoolResult.isSuccess && schoolResult.data != null) {
              _schoolTypes = schoolResult.data!;
            }
            if (communityResult.isSuccess && communityResult.data != null) {
              _communityTypes = communityResult.data!;
            }
            if (mySchoolResult.isSuccess && mySchoolResult.data != null) {
              _mySchoolCourses = mySchoolResult.data!;
            }
            if (myCommunityResult.isSuccess && myCommunityResult.data != null) {
              _myCommunityCourses = myCommunityResult.data!;
            }
            _isLoading = false;
          });

          // 如果至少有一个课程类型成功，或者至少有一个历史报名成功，就退出重试循环
          if (schoolResult.isSuccess || communityResult.isSuccess || 
              mySchoolResult.isSuccess || myCommunityResult.isSuccess) {
            break;
          }
          
          // 如果所有都失败了，进行重试
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          }
        } catch (e) {
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(milliseconds: 1000 * retryCount));
          }
        }
      }
      
      // 如果所有重试都失败了，只有当历史报名课程也获取失败时才显示错误信息
      if (retryCount >= maxRetries) {
        setState(() {
          _isLoading = false;
        });
        
        // 检查历史课程
        final hasHistoryData = _mySchoolCourses.isNotEmpty || _myCommunityCourses.isNotEmpty;
        
        if (!hasHistoryData) {
          // 历史报名课程也获取失败，显示网络错误
          _showMessage('无法连接到服务器，请检查网络设置');
        }
        // 如果能获取到历史数据但获取不到当前可报名课程，则不显示错误toast
        // 这种情况说明当前没有可报名的课程，属于正常情况
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('加载课程类型失败: $e');
    }
  }

  Future<void> _loadAllCourses(bool isSchoolBased) async {
    setState(() {
      _isLoading = true;
      _currentState = CoursePageState.selectCourse;
      _isSchoolBased = isSchoolBased;
      _currentCourseType = isSchoolBased ? '校本课程' : '社团课程';
    });

    try {
      List<Course> allCourses = [];
      Set<String> courseIds = {}; // 用于去重

      if (isSchoolBased) {
        // 加载所有校本课程类型
        for (final type in _schoolTypes) {
          final result = await CourseService.getSchoolBasedCourses(type.id);
          if (result.isSuccess && result.data != null) {
            // 去重处理
            for (final course in result.data!) {
              if (!courseIds.contains(course.id)) {
                courseIds.add(course.id);
                allCourses.add(course);
              }
            }
          }
        }
      } else {
        // 加载所有社团课程类型
        for (final type in _communityTypes) {
          final result = await CourseService.getCommunityCourses(type.id);
          if (result.isSuccess && result.data != null) {
            // 去重处理
            for (final course in result.data!) {
              if (!courseIds.contains(course.id)) {
                courseIds.add(course.id);
                allCourses.add(course);
              }
            }
          }
        }
      }

      setState(() {
        _courses = allCourses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _currentState = CoursePageState.selectType;
      });
      _showMessage('加载课程失败: $e');
    }
  }




  String _getAppBarTitle() {
    switch (_currentState) {
      case CoursePageState.selectType:
        return '课程选择';
      case CoursePageState.selectCourse:
        return _currentCourseType ?? '课程列表';
    }
  }

  void _showCourseOptions(BuildContext context, bool isSchoolBased) {
    final courseType = isSchoolBased ? '校本课程' : '社团课程';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 标题
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '选择操作',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // 选项列表
            ListTile(
              leading: Icon(
                Icons.list_alt,
                color: isSchoolBased ? const Color(0xFF007AFF) : const Color(0xFF34C759),
              ),
              title: Text(
                '查看所有$courseType',
                style: TextStyle(),
              ),
              subtitle: Text(
                '浏览所有可报名的课程',
                style: TextStyle(),
              ),
              onTap: () {
                Navigator.pop(context);
                _loadAllCourses(isSchoolBased);
              },
            ),
            
            ListTile(
              leading: Icon(
                Icons.auto_awesome,
                color: isSchoolBased ? const Color(0xFF007AFF) : const Color(0xFF34C759),
              ),
              title: Text(
                '自动抢课',
                style: TextStyle(),
              ),
              subtitle: Text(
                '系统自动为您选择课程',
                style: TextStyle(),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AutoCourseSelectionPage(),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _enrollCourse(Course course, bool isSchoolBased) async {
    // 检查重复报名
    final existingCourses = isSchoolBased ? _mySchoolCourses : _myCommunityCourses;
    if (existingCourses.isNotEmpty) {
      final courseType = isSchoolBased ? '校本课程' : '社团课程';
      _showMessage('您已经报名了$courseType，每人只能报名一门$courseType');
      return;
    }

    // 确认报名
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.school_rounded,
                color: const Color(0xFF007AFF),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '确认报名',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'HarmonyOS_SansSC',
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: 'HarmonyOS_SansSC',
              ),
              children: [
                const TextSpan(text: '确定要报名"'),
                TextSpan(
                  text: course.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF007AFF),
                  ),
                ),
                const TextSpan(text: '"吗？\n\n每人只能报名一门同类型课程。'),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                      fontFamily: 'HarmonyOS_SansSC',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: Text(
                    '确认报名',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'HarmonyOS_SansSC',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = isSchoolBased
          ? await CourseService.bookSchoolBasedCourse(course.id)
          : await CourseService.bookCommunityCourse(course.id);

      setState(() {
        _isLoading = false;
      });

      if (result.isSuccess) {
        _showMessage('报名成功！');
        // 刷新已报名课程
        _loadCourseTypes();
      } else {
        _showMessage('报名失败: ${result.message}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('报名时发生错误: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }


  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '退出登录',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'HarmonyOS_SansSC',
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '确定要退出登录吗？退出后需要重新输入账号密码。',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: 'HarmonyOS_SansSC',
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                      fontFamily: 'HarmonyOS_SansSC',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: Text(
                    '确定退出',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'HarmonyOS_SansSC',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
            ),
          );
        }
      } catch (e) {
        _showMessage('退出登录失败: $e');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        leading: _currentState == CoursePageState.selectCourse
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentState = CoursePageState.selectType;
                  });
                },
              )
            : null,
        actions: [
          if (_currentState == CoursePageState.selectType) ...[
            IconButton(
              onPressed: _isLoading ? null : _loadCourseTypes,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              tooltip: '刷新课程类型',
            ),
          ],
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            offset: const Offset(0, 50), // 向下偏移，避免遮挡按钮
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            color: Colors.white,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.red.withValues(alpha: 0.05),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.logout_rounded, 
                          size: 16,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '退出登录',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                          fontFamily: 'HarmonyOS_SansSC',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.more_vert_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerContent(context, isMobile)
          : _buildCurrentState(context, isMobile),
    );
  }

  Widget _buildShimmerContent(BuildContext context, bool isMobile) {
    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 欢迎区域
            ShimmerWidgets.welcomeSectionShimmer(),
            const SizedBox(height: 24),
            
            // 已报名课程
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerWidgets.shimmerWrapper(
                    child: Container(
                      height: 20,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShimmerWidgets.buildShimmerList(
                    itemBuilder: () => ShimmerWidgets.enrolledCourseCardShimmer(),
                    itemCount: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 课程类型
            ShimmerWidgets.buildShimmerList(
              itemBuilder: () => ShimmerWidgets.courseTypeCardShimmer(),
              itemCount: 2,
            ),
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧shimmer
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerWidgets.shimmerWrapper(
                          child: Container(
                            height: 20,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShimmerWidgets.buildShimmerList(
                          itemBuilder: () => ShimmerWidgets.enrolledCourseCardShimmer(),
                          itemCount: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                // 右侧shimmer
                Expanded(
                  flex: 1,
                  child: ShimmerWidgets.buildShimmerList(
                    itemBuilder: () => ShimmerWidgets.courseTypeCardShimmer(),
                    itemCount: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildCurrentState(BuildContext context, bool isMobile) {
    switch (_currentState) {
      case CoursePageState.selectType:
        return _buildTypeSelection(context, isMobile);
      case CoursePageState.selectCourse:
        return _buildCourseSelection(context, isMobile);
    }
  }

  Widget _buildTypeSelection(BuildContext context, bool isMobile) {
    if (isMobile) {
      return _buildMobileLayout(context);
    } else {
      return _buildDesktopLayout(context);
    }
  }

  Widget _buildMobileLayout(BuildContext context) {
    return AnimatedWidgets.fadeIn(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedWidgets.slideInUp(
              child: _buildWelcomeSection(context),
            ),
            const SizedBox(height: 24),
            AnimatedWidgets.slideInUp(
              delay: const Duration(milliseconds: 200),
              child: _buildEnrolledCoursesSection(context),
            ),
            const SizedBox(height: 24),
            AnimatedWidgets.slideInUp(
              delay: const Duration(milliseconds: 400),
              child: _buildCourseTypesSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return AnimatedWidgets.fadeIn(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧：我的课程
                Expanded(
                  flex: 1,
                  child: AnimatedWidgets.slideInUp(
                    child: _buildEnrolledCoursesSection(context),
                  ),
                ),
                const SizedBox(width: 32),
                // 右侧：选择课程类型
                Expanded(
                  flex: 1,
                  child: AnimatedWidgets.slideInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _buildCourseTypesSection(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey[200] ?? Colors.grey,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '欢迎回来，$_userName',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1D1D1F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '请选择您要查看的课程类型',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseItem(BuildContext context, Course course, bool isSchoolBased) {
    final isEnrolled = isSchoolBased 
        ? _mySchoolCourses.any((c) => c.id == course.id)
        : _myCommunityCourses.any((c) => c.id == course.id);
    
    return AnimatedWidgets.animatedCard(
      onTap: () {
        Navigator.push(
          context,
          AnimatedWidgets.slidePageRoute(
            page: CourseDetailPage(
              course: course, 
              courseType: isSchoolBased ? '校本课程' : '社团课程',
            ),
            direction: SlideDirection.right,
          ),
        );
      },
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (course.teacher != null && course.teacher!.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '教师：${course.teacher}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (course.time != null && course.time!.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '时间：${course.time}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (course.location != null && course.location!.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '地点：${course.location}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (course.capacity != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${course.enrolled ?? 0}/${course.capacity} 人',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      if (isEnrolled) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '已报名',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ElevatedButton(
                          onPressed: () => _enrollCourse(course, isSchoolBased),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSchoolBased ? const Color(0xFF007AFF) : const Color(0xFF34C759),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            '报名',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseTypesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择课程类型',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        
        // 校本课程卡片
        _buildSimpleCourseCard(
          context,
          '校本课程',
          const Color(0xFF007AFF),
          _mySchoolCourses.length,
          () => _showCourseOptions(context, true),
        ),
        const SizedBox(height: 16),
        
        // 社团课程卡片
        _buildSimpleCourseCard(
          context,
          '社团课程',
          const Color(0xFF34C759),
          _myCommunityCourses.length,
          () => _showCourseOptions(context, false),
        ),
      ],
    );
  }

  Widget _buildSimpleCourseCard(BuildContext context, String title, Color color, int enrolledCount, VoidCallback onTap) {
    return AnimatedWidgets.animatedCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.05),
              color.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    title == '校本课程' ? Icons.school_rounded : Icons.groups_rounded,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击查看所有课程',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 20,
                ),
              ],
            ),
            if (enrolledCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '已报名 $enrolledCount 门课程',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnrolledCoursesSection(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '我的课程',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // 校本课程已报名
        _buildEnrolledCourseCard(
          context,
          '校本课程',
          const Color(0xFF007AFF),
          _mySchoolCourses,
          isMobile,
        ),
        const SizedBox(height: 12),
        
        // 社团课程已报名
        _buildEnrolledCourseCard(
          context,
          '社团课程',
          const Color(0xFF34C759),
          _myCommunityCourses,
          isMobile,
        ),
      ],
    );
  }

  Widget _buildEnrolledCourseCard(BuildContext context, String title, Color color, List<Course> courses, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.05),
            color.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  title == '校本课程' ? Icons.school_rounded : Icons.groups_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${courses.length} 门',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          
          if (courses.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '暂无已报名课程',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            // 显示前3门课程，如果超过3门则显示"查看更多"
            ...courses.take(3).map((course) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseDetailPage(
                        course: course,
                        courseType: title,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (course.teacher != null && course.teacher!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '教师：${course.teacher}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: color,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            )),
            
            if (courses.length > 3) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showAllEnrolledCourses(context, title, courses),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '查看全部 ${courses.length} 门课程',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showAllEnrolledCourses(BuildContext context, String courseType, List<Course> courses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    courseType == '校本课程' ? Icons.school_rounded : Icons.groups_rounded,
                    color: courseType == '校本课程' ? const Color(0xFF007AFF) : const Color(0xFF34C759),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '我的$courseType',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // 课程列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return _buildCourseItem(context, course, courseType == '校本课程');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

    
  Widget _buildCourseSelection(BuildContext context, bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          
          // 课程列表
          if (_courses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                              Icon(
                      Icons.info_outline_rounded,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                          Text(
                      '暂无课程',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                          Text(
                      '请稍后重试或联系管理员',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _courses.length,
              itemBuilder: (context, index) {
                final course = _courses[index];
                return AnimatedWidgets.animatedListItem(
                  index: index,
                  child: _buildCourseItem(context, course, _isSchoolBased),
                );
              },
            ),
        ],
      ),
    );
  }
}

// 页面状态枚举
enum CoursePageState {
  selectType,
  selectCourse,
}
