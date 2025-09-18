# GZOA - 选课APP

这个应用只是为了替代那个性能差的离谱还不好用的学校选课应用，并且支持了自动抢课功能，我们贴心的为大家准备了双账号抢课的功能，帮助你和ta一起选上同一个心仪的课

#

## 项目结构

```
lib/
├── main.dart                 # 主应用文件
├── utils/                    # 工具类
├── services/                 # 服务类
...更多文件
```

## 功能说明

###  登录功能
应用启动时会检查登录状态，如果未登录则显示登录页面。

**登录要求：**
- 学号：用户的学生学号
- 密码：一般是与学号相同的密码

**API规格：**
- 端点：`baseurl/api/ApiStudent/Login`
- 方法：POST
- 认证：成功后返回ApiToken用于后续操作

###  抢课功能
登录成功后进入抢课主界面，提供完整的课程选择体验。


**API接口：**
- 校本课程：`/ApiBooking/GetTypeList?t={timestamp}`, `/ApiBooking/GetCourseList?t={timestamp}`, `/ApiBooking/SetBooking?t={timestamp}`
- 社团课程：`/ApiCommunityClass/GetTypeList?t={timestamp}`, `/ApiCommunityClass/GetCourseList?t={timestamp}`, `/ApiCommunityClass/SetBooking?t={timestamp}`
- 已报名课程：`/ApiBooking/GetCourses?t={timestamp}`, `/ApiCommunityClass/GetCourses?t={timestamp}`
- 认证方式：HTTP Header中的token字段
- 时间戳：所有API调用都包含时间戳参数


## 运行应用

### 前提条件
- Flutter SDK 3.9.2 或更高版本
- Android Studio / Xcode / Visual Studio
- 相应的平台开发环境

### 安装依赖
```bash
flutter pub get
```

### 运行在不同平台

#### Android
```bash
flutter run -d android
```

#### iOS
```bash
flutter run -d ios
```

#### Windows
```bash
flutter run -d windows
```

#### 所有平台
```bash
flutter run
```

## 贡献

欢迎提交Issue和Pull Request来改进这个项目！

## 许可证

MIT License