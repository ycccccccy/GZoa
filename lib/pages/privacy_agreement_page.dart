import 'package:flutter/material.dart';
import '../services/privacy_service.dart';
import '../utils/responsive_utils.dart';
import '../utils/status_bar_utils.dart';
import '../widgets/animated_widgets.dart';
import 'login_page.dart';

class PrivacyAgreementPage extends StatefulWidget {
  const PrivacyAgreementPage({super.key});

  @override
  State<PrivacyAgreementPage> createState() => _PrivacyAgreementPageState();
}

class _PrivacyAgreementPageState extends State<PrivacyAgreementPage> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    StatusBarUtils.setLightStatusBar();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.atEdge && 
        _scrollController.position.pixels != 0) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  Future<void> _acceptPrivacy() async {
    setState(() {
      _isAccepting = true;
    });

    try {
      final success = await PrivacyService.acceptPrivacy();
      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          AnimatedWidgets.slidePageRoute(
            page: const LoginPage(),
            direction: SlideDirection.right,
          ),
        );
      } else if (mounted) {
        _showErrorDialog('保存设置时出现错误，请重试');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('操作失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
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
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '操作失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'HarmonyOS_SansSC',
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontFamily: 'HarmonyOS_SansSC',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    '隐私协议与免责声明',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 800,
                  ),
                  child: AnimatedWidgets.fadeIn(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSection(
                              '重要提示',
                              '本应用是一款为方便用户进行课程信息查询与管理而设计的本地客户端工具。本应用不提供任何形式的网络服务，所有数据交互均在用户本地设备与目标站点之间直接发生。请您在继续使用前，仔细阅读并充分理解以下所有条款。',
                              isImportant: true,
                            ),
                            
                            _buildSection(
                              '1. 总则：软件性质与定位',
                              '本应用本质上是一个提供图形用户界面的自动化操作辅助工具，其功能类似于一个带有自动化脚本的浏览器。它本身不抓取、不存储、不分析、不共享任何用户数据。所有操作（包括但不限于信息查询、点击、提交等）均由用户在本地设备上发起，并由用户对这些操作的意图和后果承担全部责任。',
                            ),
                            
                            _buildSection(
                              '2. 免责声明',
                              '在任何情况下，本应用的开发者均不对以下任何情形承担任何直接、间接、偶然、特殊或衍生的损害赔偿责任：\n'
                              '• 因使用或无法使用本应用所造成的任何损失；\n'
                              '• 通过本应用进行的任何操作所导致的一切后果，包括但不限于课程选择结果、账号状态异常、与校方的任何纠纷等；\n'
                              '• 因学校官方系统升级、规则变更或网络波动等不可抗力因素导致的应用功能失效或数据错误；\n'
                              '• 任何第三方未经授权访问或更改您的数据所造成的损失。',
                            ),
                            
                            _buildSection(
                              '3. 用户责任与行为准则',
                              '您作为本应用的唯一使用者，需对您的所有行为负全部责任：\n'
                              '• 您承诺将严格遵守您所在学校的所有规章制度以及国家相关法律法规；\n'
                              '• 您应对您输入的账号、密码等信息的安全负全部责任。强烈建议您在使用后及时清除相关信息；\n'
                              '• 您应对您设置的操作频率、时间和方式负全部责任。因操作不当（如频率过高）所引起的任何问题（包括但不限于IP被限制、账号被锁定等），均由您自行承担。',
                            ),
                            
                            _buildSection(
                              '4. 数据隐私与安全',
                              '本应用高度重视用户数据隐私：\n'
                              '• **本地存储**：您的所有个人敏感信息（如学号、密码等）仅加密存储在您的设备本地，开发者无法也绝不会访问、上传或泄露您的任何个人信息；\n'
                              '• **无服务器设计**：本应用不设有后台服务器来中转或处理您的数据。所有网络请求均由您的设备直接发送至学校官方服务器；\n'
                              '• **风险自担**：尽管我们已采取了合理的本地加密措施，但无法保证在任何极端情况下（如您的设备被病毒入侵）的数据安全。您需自行承担本地数据泄露的风险。',
                            ),
                            
                            _buildSection(
                              '5. 功能与服务的不保证声明',
                              '本应用按"现状"提供，不提供任何形式的明示或默示保证：\n'
                              '• **无成功保证**：本应用不保证任何操作的成功率，课程选择结果完全取决于学校系统的实际处理情况；\n'
                              '• **无时效保证**：开发者没有义务对本应用进行持续维护、更新或对任何BUG进行修复。应用可能随时因不可抗力而停止工作；\n'
                              '• **非官方性质**：本应用为个人开发的技术研究项目，与您所在的学校没有任何关联。请勿将本应用的功能与官方服务混淆。',
                            ),
                            
                            _buildSection(
                              '6. 知识产权',
                              '本应用的所有知识产权（包括但不限于软件著作权）归开发者所有。严禁对本应用进行任何形式的逆向工程、反编译、破解或用于任何商业目的。',
                            ),
                            
                            _buildSection(
                              '7. 协议的接受与变更',
                              '当您点击"同意"按钮时，即表示您已阅读、理解并同意接受本协议所有条款的约束。开发者保留随时修改本协议的权利，修改后的协议将在应用内公布。若您不同意修改后的协议，请立即停止使用本应用。',
                            ),
                            
                            _buildSection(
                              '8. 争议解决',
                              '因使用本应用产生的任何争议，您同意均与开发者无关。您承诺放弃就任何因您个人行为所引发的纠纷将开发者列为诉讼方或责任方的权利。',
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    color: Colors.orange[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '请再次确认：您理解本应用仅为一款本地执行的辅助工具。您将对使用本工具的所有行为及其产生的一切后果独立承担全部法律和纪律责任。如果您不接受此条款，请立即退出并卸载本应用。',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'HarmonyOS_SansSC',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Bottom Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    offset: const Offset(0, -2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (!_hasScrolledToBottom)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, 
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '请滚动到底部阅读完整内容',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontFamily: 'HarmonyOS_SansSC',
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            side: BorderSide(
                              color: Colors.grey.shade400,
                            ),
                          ),
                          child: const Text(
                            '拒绝使用',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: (!_hasScrolledToBottom || _isAccepting) 
                              ? null 
                              : _acceptPrivacy,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isAccepting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  '同意并继续使用',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, {bool isImportant = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isImportant ? Colors.red[700] : Colors.black87,
              fontFamily: 'HarmonyOS_SansSC',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: isImportant ? const EdgeInsets.all(12) : EdgeInsets.zero,
            decoration: isImportant ? BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.2),
              ),
            ) : null,
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isImportant ? Colors.red[800] : Colors.grey[700],
                fontFamily: 'HarmonyOS_SansSC',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
