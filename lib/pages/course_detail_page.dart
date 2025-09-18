import 'package:flutter/material.dart';
import '../services/course_service.dart';

class CourseDetailPage extends StatelessWidget {
  final Course course;
  final String courseType;

  const CourseDetailPage({
    Key? key,
    required this.course,
    required this.courseType,
  }) : super(key: key);

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
          '课程详情',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 课程标题卡片
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: courseType == '校本课程' 
                    ? const Color(0xFF007AFF).withValues(alpha: 0.2)
                    : const Color(0xFF34C759).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: courseType == '校本课程' 
                              ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                              : const Color(0xFF34C759).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            courseType == '校本课程' 
                              ? Icons.school 
                              : Icons.groups,
                            color: courseType == '校本课程' 
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF34C759),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                courseType,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: courseType == '校本课程' 
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFF34C759),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 课程信息详情
            _buildInfoSection(
              context,
              '基本信息',
              [
                _buildInfoItem('课程名称', course.name),
                _buildInfoItem('课程类型', courseType),
                if (course.teacher != null && course.teacher!.isNotEmpty)
                  _buildInfoItem('授课教师', course.teacher!),
                if (course.location != null && course.location!.isNotEmpty)
                  _buildInfoItem('上课地点', course.location!),
                if (course.time != null && course.time!.isNotEmpty)
                  _buildInfoItem('上课时间', course.time!),
                if (course.credits != null)
                  _buildInfoItem('学分', '${course.credits}分'),
                if (course.capacity != null)
                  _buildInfoItem('课程容量', '${course.capacity}人'),
                if (course.enrolled != null)
                  _buildInfoItem('已选人数', '${course.enrolled}人'),
              ],
            ),
            
            if (course.description != null && course.description!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildInfoSection(
                context,
                '课程描述',
                [
                  _buildInfoItem('', course.description!, isDescription: true),
                ],
              ),
            ],
            
            const SizedBox(height: 24),
            
            // 状态信息
            _buildInfoSection(
              context,
              '选课状态',
              [
                _buildInfoItem('选课状态', '已报名'),
                _buildInfoItem('课程状态', course.isAvailable ? '可选' : '不可选'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, String title, List<Widget> items) {
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
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool isDescription = false}) {
    if (isDescription) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
