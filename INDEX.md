# todo-ng 项目索引

## 1. 项目概览
- 技术栈: Flutter + Dart + SQLite (`sqflite`)。
- 核心能力: 任务管理、提醒通知、重复规则、日历视图、完成任务管理、动作执行（电话/导航/会议/网页/消息）、Markdown 描述编辑、多语言（中英）。
- 应用入口: `lib/main.dart`。

## 2. 顶层目录索引
- `lib/`: 业务代码（UI、数据层、服务层、工具函数、组件、国际化）。
- `assets/`: 应用 SVG 资源（图标等）。
- `img/`: README 与启动图相关图片资源。
- `android/`、`ios/`: 平台工程与原生配置。
- `README.md`: 项目介绍与使用说明。
- `project.md`: 当前仓库内的补充说明文档。
- `pubspec.yaml`: 依赖、资源、Flutter 配置。

## 3. 代码结构（lib）

### 3.1 入口与全局
- `lib/main.dart`
  - 初始化通知渠道与权限。
  - 启动时重排任务通知。
  - 初始化配置服务（语言等）。
  - 注册路由：`home` / `add_task` / `edit_task` / `settings`。

### 3.2 models（领域模型）
- `lib/models/task_entity.dart`: 核心任务实体，含时间类型、优先级、提醒、重复规则、动作列表映射。
- `lib/models/action_item.dart`: 单个动作项模型（type/data/target）。

### 3.3 data（持久化）
- `lib/data/database_service.dart`: SQLite 单例与版本迁移（当前 DB version = 7）。
- `lib/data/task_dao.dart`: `tasks` 表 CRUD、状态切换、筛选与示例数据。

### 3.4 repositories（仓储）
- `lib/repositories/task_repository.dart`: 对外数据门面，协调 DAO 与通知服务。

### 3.5 services（系统/配置服务）
- `lib/services/notification_service.dart`: 本地通知调度、取消、重排。
- `lib/services/system_alarm_service.dart`: Android 系统闹钟能力与权限跳转。
- `lib/services/config_service.dart`: 本地配置（语言、会议 scheme、电话区号）。

### 3.6 screens（页面层）
- `lib/screens/main_scaffold.dart`: 主容器与底部导航。
- `lib/screens/home_page.dart`: 主任务列表与筛选。
- `lib/screens/calendar_page.dart`: 日历视图、按日期聚合、批量改期。
- `lib/screens/completed_tasks_page.dart`: 已完成任务列表、排序与批量删除。
- `lib/screens/add_task_page.dart`: 新建任务页。
- `lib/screens/edit_task_page.dart`: 编辑任务页。
- `lib/screens/settings_page.dart`: 设置页（通知、语言、动作默认项、清空数据等）。

### 3.7 widgets（复用组件）
- `lib/widgets/date_time_picker_section.dart`: 时间/日期与时间类型选择。
- `lib/widgets/repeat_picker_field.dart`: 重复规则选择（天/周/月/年）。
- `lib/widgets/reminder_setting_field.dart`: 提醒策略与系统闹钟开关。
- `lib/widgets/priority_picker_field.dart`: 任务优先级选择。
- `lib/widgets/action_selector.dart`: 动作配置（多动作）。
- `lib/widgets/action_button.dart`: 动作执行按钮。
- `lib/widgets/description_markdown_field.dart`: 描述区 Markdown 编辑。
- `lib/widgets/markdown_editor_sheet.dart`: 全屏 Markdown 编辑器。
- `lib/widgets/task_detail_sheet.dart`: 任务详情编辑底部面板。

### 3.8 utils（工具层）
- `lib/utils/recurrence_utils.dart`: 重复规则与发生时间计算。
- `lib/utils/action_executor.dart`: 动作执行调度（电话/导航/会议/网页/消息）。
- `lib/utils/app_launcher.dart`: URL Scheme 打开与降级策略。
- `lib/utils/meeting_utils.dart`: 会议链接与会议号解析/校验。
- `lib/utils/url_schemes.dart`: 各动作对应 scheme 常量。
- `lib/utils/priority_utils.dart`: 优先级到颜色/文案映射。

### 3.9 l10n（国际化）
- `lib/l10n/app_en.arb`、`lib/l10n/app_zh.arb`: 文案资源。
- `lib/l10n/app_localizations*.dart`: 生成的本地化代码。

## 4. 核心数据流
1. UI (`screens/widgets`) 发起任务操作。
2. `TaskRepository` 执行业务编排。
3. `TaskDao` 读写 SQLite `tasks` 表。
4. `NotificationService` 按任务状态维护提醒。

## 5. 数据库速览
- DB 文件名: `doable.db`
- 表: `tasks`
- 关键字段: `title`, `description`, `date`, `time`, `time_kind`, `end_date`, `end_time`, `has_notification`, `reminder_time`, `repeat_rule`, `priority`, `actions`, `completed`。
- 迁移逻辑: 见 `lib/data/database_service.dart` 的 `onUpgrade`。

## 6. 主要依赖（摘录）
- 数据与存储: `sqflite`, `shared_preferences`, `path`
- 时间与日历: `intl`, `table_calendar`, `timezone`
- 通知与提醒: `awesome_notifications`, `permission_handler`, `flutter_alarm_clock`
- UI 与交互: `flutter_svg`, `flutter_slidable`, `flutter_markdown`
- 外部跳转: `url_launcher`, `android_intent_plus`

## 7. 常用开发命令
```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

## 8. 建议阅读顺序
1. `lib/main.dart`
2. `lib/screens/main_scaffold.dart`
3. `lib/screens/home_page.dart`
4. `lib/repositories/task_repository.dart`
5. `lib/data/task_dao.dart`
6. `lib/data/database_service.dart`
7. `lib/services/notification_service.dart`
