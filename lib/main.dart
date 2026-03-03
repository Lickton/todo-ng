import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:doable_todo_list_app/l10n/app_localizations.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/screens/add_task_page.dart';
import 'package:doable_todo_list_app/screens/edit_task_page.dart';
import 'package:doable_todo_list_app/screens/main_scaffold.dart';
import 'package:doable_todo_list_app/screens/settings_page.dart';
import 'package:doable_todo_list_app/services/config_service.dart';
import 'package:doable_todo_list_app/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全局颜色常量。
/// 这些颜色会在多个页面复用，放在入口文件便于统一维护。
Color blackColor = const Color(0xff0c120c);
Color blueColor = const Color(0xff4285F4);
Color whiteColor = const Color(0xffFDFDFF);
Color iconColor = const Color(0xff565656);
Color outlineColor = const Color(0xffD6D6D6);
Color descriptionColor = const Color(0xff565656);

/// 应用启动入口。
/// 主要做三件事：
/// 1) 初始化 Flutter 与通知能力；
/// 2) 启动时尝试恢复任务提醒；
/// 3) 初始化配置后挂载根组件。
Future<void> main() async {
  // 在 runApp 之前调用平台通道（通知、数据库、配置）时必须先初始化绑定。
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知插件与渠道（Android 侧会用 channelKey 进行归类）。
  await AwesomeNotifications().initialize(
    null, // 使用默认通知图标（未指定自定义资源名）。
    [
      NotificationChannel(
        channelKey: 'task_reminders',
        channelName: 'Task Reminders',
        channelDescription: 'Notifications for task reminders',
        defaultColor: blueColor,
        ledColor: blueColor,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        playSound: true,
        enableVibration: true,
      ),
    ],
  );

  // 请求通知权限（在部分平台是运行时权限）。
  final hasPermission = await NotificationService.requestPermissions();
  if (!hasPermission) {
    print('Notification permission denied');
  } else {
    print('Notification permission granted');
  }

  // 应用重启后根据数据库中的任务重新安排提醒，避免提醒丢失。
  try {
    final tasks = await TaskRepository().fetchAll();
    print('Rescheduling ${tasks.length} tasks');
    await NotificationService.rescheduleAllNotifications(tasks);
    print('Notifications rescheduled successfully');
  } catch (e) {
    print('Error rescheduling notifications: $e');
  }

  // 统一系统状态栏/导航栏样式，使系统栏与应用浅色主题一致。
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: whiteColor,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: whiteColor,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: whiteColor));

  // 初始化本地配置（如语言偏好、动作默认设置等）。
  await ConfigService.init();

  // 启动应用。
  runApp(const DoableApp());
}

/// 根组件：承载全局导航、路由、主题与本地化。
class DoableApp extends StatefulWidget {
  const DoableApp({super.key});

  // 全局 NavigatorKey：用于在通知回调等无 BuildContext 场景下进行页面跳转。
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<DoableApp> createState() => _DoableAppState();
}

class _DoableAppState extends State<DoableApp> {
  @override
  void initState() {
    super.initState();

    // 注册通知生命周期监听：
    // - onActionReceivedMethod: 用户点击通知或通知按钮
    // - onNotificationCreatedMethod: 通知创建
    // - onNotificationDisplayedMethod: 通知展示
    // - onDismissActionReceivedMethod: 通知被清除/关闭
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    // 处理通知点击行为。
    // 约定：如果 payload 中带有 task_id，说明这条通知关联任务。
    if (receivedAction.payload?['task_id'] != null) {
      // 清空当前路由栈并回到主页，确保用户从任意状态都能落到任务主界面。
      DoableApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        'home',
        (route) => false,
      );
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    // 预留：可在这里接入埋点或日志（当前无额外逻辑）。
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    // 预留：可在这里处理通知展示后的统计或状态同步。
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    // 预留：可在这里处理通知被用户忽略/移除后的回调逻辑。
  }

  @override
  Widget build(BuildContext context) {
    // 监听语言配置变化：当 localeNotifier 更新时，MaterialApp 会自动重建并切换文案。
    return ValueListenableBuilder<String>(
      valueListenable: ConfigService.instance.localeNotifier,
      builder: (_, __, ___) {
        final config = ConfigService.instance;
        final locale = config.effectiveLocale;
        return MaterialApp(
          // 使用全局 navigatorKey 支持跨层级跳转（例如通知点击）。
          navigatorKey: DoableApp.navigatorKey,
          // 当前生效语言（跟随配置服务）。
          locale: locale,
          // 应用支持的语言集合（由 l10n 生成代码提供）。
          supportedLocales: AppLocalizations.supportedLocales,
          // 本地化代理：加载对应语言资源。
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // 首屏容器页（底部导航 + 多页面）。
          home: const MainScaffold(),
          // 关闭右上角 debug 标识。
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              // 统一禁用默认水波纹/悬停色，保持当前设计风格更“干净”。
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              // 全局字体族。
              fontFamily: "Inter",
              textTheme: const TextTheme(
                // 一级标题：如创建/编辑页面大标题。
                displayLarge: TextStyle(
                    fontSize: 28.0,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff0c120c)),
                // 二级标题：如 Today、Settings。
                displayMedium: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff0c120c)),
                // 常规按钮/标签文字：如 Save、Set Reminder。
                displaySmall: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff0c120c)),
                // 分区标题：如 Date & Time、Completion status。
                labelSmall: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff565656)),
                // 任务标题文字样式。
                bodyLarge: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff0c120c)),
                // 任务描述文字样式。
                bodyMedium: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff565656)),
                // 任务时间/日期等辅助信息样式。
                bodySmall: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.normal,
                    color: Color(0xff565656)),
              )),
          // 默认入口路由名。
          initialRoute: 'home',
          // 命名路由表：统一管理页面跳转目标。
          routes: {
            'home': (context) => const MainScaffold(),
            'add_task': (context) => const AddTaskPage(),
            'edit_task': (context) => const EditTaskPage(),
            'settings': (context) => const SettingsPage(),
          },
        );
      },
    );
  }
}

/// 根据屏幕高度计算通用垂直间距。
double verticalPadding(BuildContext context) {
  return MediaQuery.of(context).size.height / 20;
}

/// 根据屏幕宽度计算通用水平间距。
double horizontalPadding(BuildContext context) {
  return MediaQuery.of(context).size.width / 20;
}

/// 统一文本输入框内边距，随屏幕尺寸按比例缩放。
EdgeInsets textFieldPadding(BuildContext context) {
  return EdgeInsets.symmetric(
      horizontal: MediaQuery.of(context).size.width * 0.1,
      vertical: MediaQuery.of(context).size.height * 0.025);
}
