import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../services/course_service.dart';
import '../utils/status_bar_utils.dart';
import '../widgets/animated_widgets.dart';
import 'course_detail_page.dart';

class AllCoursesPage extends StatefulWidget {
  final bool isSchoolBased;

  const AllCoursesPage({super.key, required this.isSchoolBased});

  @override
  State<AllCoursesPage> createState() => _AllCoursesPageState();
}

class _AllCoursesPageState extends State<AllCoursesPage> {
  bool _isLoading = true;
  List<Course> _courses = [];
  List<Course> _myEnrolledCourses = [];
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    StatusBarUtils.setLightStatusBar();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 并行加载所有课程和已报名课程
      final results = await Future.wait([
        widget.isSchoolBased
            ? CourseService.getAllSchoolBasedCourses()
            : CourseService.getAllCommunityCourses(),
        widget.isSchoolBased
            ? CourseService.getMySchoolBasedCourses()
            : CourseService.getMyCommunityCourses(),
      ]);

      final allCoursesResult = results[0];
      final myCoursesResult = results[1];

      if (mounted) {
        if (allCoursesResult.isSuccess && allCoursesResult.data != null) {
      setState(() {
            _courses = allCoursesResult.data!;
          });
        } else {
          _errorMessage = '加载课程列表失败: ${allCoursesResult.message}';
        }

        if (myCoursesResult.isSuccess && myCoursesResult.data != null) {
    setState(() {
            _myEnrolledCourses = myCoursesResult.data!;
          });
        }
        // 已报名课程加载失败不阻碍显示所有课程，所以不设置errorMessage

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
      setState(() {
        _isLoading = false;
          _errorMessage = '加载数据时发生错误: $e';
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.grey[800],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _enrollCourse(Course course) async {
    // 检查重复报名
    if (_myEnrolledCourses.isNotEmpty) {
      final courseType = widget.isSchoolBased ? '校本课程' : '社团课程';
      _showMessage('您已经报名了$courseType，每人只能报名一门$courseType');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildBookingConfirmationDialog(course),
    );

    if (confirmed != true) return;

    final result = widget.isSchoolBased
          ? await CourseService.bookSchoolBasedCourse(course.id)
          : await CourseService.bookCommunityCourse(course.id);

    if (mounted) {
      if (result.isSuccess) {
        _showMessage('报名成功！');
        await _loadData(); // 报名完需要刷新所有数据
      } else {
        _showMessage('报名失败: ${result.message}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.isSchoolBased ? '所有校本课程' : '所有社团课程',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
                          fontFamily: 'HarmonyOS_SansSC',
                        ),
                      ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _buildCourseContent(),
    );
  }

  Widget _buildCourseContent() {
    if (_isLoading) {
      return _buildCourseListShimmer();
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
              child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
                children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_courses.isEmpty) {
      return const Center(
        child: Text(
          '当前没有可报名的课程',
          style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          return AnimatedWidgets.animatedListItem(
            index: index,
            child: _buildCourseItem(context, course),
          );
        },
      ),
    );
  }

  Widget _buildCourseItem(BuildContext context, Course course) {
    final isEnrolled = _myEnrolledCourses.any((c) => c.id == course.id);
    
    return AnimatedWidgets.animatedCard(
      onTap: () {
        Navigator.push(
          context,
          AnimatedWidgets.slidePageRoute(
            page: CourseDetailPage(
              course: course, 
              courseType: widget.isSchoolBased ? '校本课程' : '社团课程',
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
                                fontFamily: 'HarmonyOS_SansSC',
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (course.teacher != null && course.teacher!.isNotEmpty)
                          _buildInfoRow(Icons.person_outline, '教师：${course.teacher}'),
                        if (course.time != null && course.time!.isNotEmpty)
                           _buildInfoRow(Icons.access_time, '时间：${course.time}'),
                        if (course.location != null && course.location!.isNotEmpty)
                          _buildInfoRow(Icons.location_on_outlined, '地点：${course.location}'),
                        if (course.capacity != null)
                           _buildInfoRow(Icons.people_outline, '${course.enrolled ?? 0}/${course.capacity} 人'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      if (isEnrolled)
                        _buildStatusChip(text: '已报名', icon: Icons.check_circle, color: Colors.green)
                      else
                        ElevatedButton(
                          onPressed: () => _enrollCourse(course),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isSchoolBased
                                ? const Color(0xFF007AFF)
                                : const Color(0xFF34C759),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            '报名',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              fontFamily: 'HarmonyOS_SansSC',
                            ),
                          ),
                        ),
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

  Widget _buildStatusChip({required String text, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
        color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
                    Text(
            text,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
              fontSize: 12,
              fontFamily: 'HarmonyOS_SansSC',
                      ),
                    ),
                  ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
      children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14, 
                color: Colors.grey[800],
                fontFamily: 'HarmonyOS_SansSC'
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingConfirmationDialog(Course course) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.school_rounded, color: Color(0xFF007AFF), size: 20),
              ),
              const SizedBox(width: 12),
          const Text(
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
              const TextSpan(text: '确定要报名 "'),
              TextSpan(
                text: course.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
              const TextSpan(text: '" 吗？\n\n每人只能报名一门同类型课程。'),
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
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text(
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
    );
  }

  Widget _buildCourseListShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
        child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  Row(
                children: [
                  Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                            Container(width: double.infinity, height: 20.0, color: Colors.white),
                            const SizedBox(height: 10),
                            Container(width: 150.0, height: 16.0, color: Colors.white),
                             const SizedBox(height: 6),
                            Container(width: 200.0, height: 16.0, color: Colors.white),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(width: 80.0, height: 36.0, color: Colors.white),
                    ],
                              ),
                          ],
                        ),
              ),
          );
        },
      ),
    );
  }
}
