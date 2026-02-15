
已收集到足够信息，正在整理为 Markdown 格式的分析报告。
`</think>`
根据当前代码，整理出的项目分析如下（Markdown 格式）：

---

# Flutter TODO 应用项目结构分析

## 1. 关键文件及职责

| 路径 | 职责 |
|------|------|
| **`lib/main.dart`** | 应用入口：初始化 Awesome Notifications、请求通知权限、启动时通过 `TaskRepository().fetchAll()` 拉取任务并调用 `NotificationService.rescheduleAllNotifications` 重新调度通知；定义全局颜色、主题、路由（home / add_task / edit_task / settings）；注册通知点击/创建/展示/关闭回调。 |
| **`lib/models/task_entity.dart`** | 领域模型：定义任务实体字段、`fromMap`/`toMap` 与 SQLite 表 `tasks` 的映射（含 snake_case 列名转换）。 |
| **`lib/data/database_service.dart`** | 数据库单例：使用 **sqflite** 管理 `doable.db`，负责 `openDatabase`、`onCreate` 建表、`onUpgrade` 预留迁移。 |
| **`lib/data/task_dao.dart`** | 数据访问层：对 `tasks` 表的 CRUD（insert/update/delete/getAll/getById）、`toggleCompleted`、`clearAll`，以及可选的 `seedDemo`；直接使用 `DatabaseService.instance()` 和 `TaskEntity.toMap/fromMap`。 |
| **`lib/repositories/task_repository.dart`** | 业务仓库：封装 `TaskDao`，并在增删改、toggle 时协调 **NotificationService**（新增/更新/取消/重排提醒）。对外提供 `fetchAll`、`add`、`update`、`delete`、`toggle`、`seedDemo`、`clearAll`。 |
| **`lib/services/notification_service.dart`** | 通知服务：基于 **awesome_notifications** 调度/取消单任务或全部提醒；解析 `TaskEntity` 的 date/time 字符串；依赖 **SharedPreferences** 判断用户是否开启通知（`notifications_enabled`）。 |
| **`lib/screens/home_page.dart`** | 首页：通过 `TaskRepository().fetchAll()` 加载任务，转为本地 `Task` 展示；支持筛选（日期、时间、完成状态、重复规则、提醒）；列表项支持勾选完成、左滑删除、点击进入编辑；FAB 进入添加任务。 |
| **`lib/screens/add_task_page.dart`** | 添加任务页：表单（标题、描述、提醒开关、重复、日期时间）提交时构造 `TaskEntity`，调用 `TaskRepository().add(entity)`，成功后 `pop(context, true)` 通知首页刷新。 |
| **`lib/screens/edit_task_page.dart`** | 编辑任务页：从路由参数取得 `Task`，预填表单，保存时构造带 `id` 的 `TaskEntity`，调用 `TaskRepository().update(entity)`，成功后 `pop(context, true)`。 |
| **`lib/screens/settings_page.dart`** | 设置页：通知总开关（持久化到 SharedPreferences）、清除全部数据（`TaskRepository().clearAll()`）、版本与许可信息、外链（Twitter/GitHub/LinkedIn）。 |

---

## 2. 数据流向：UI → Repository → DAO → Database

```
┌─────────────────────────────────────────────────────────────────────────┐
│  UI (Screens)                                                            │
│  HomePage / AddTaskPage / EditTaskPage / SettingsPage                    │
│  - 只依赖 TaskRepository（及 Home 的本地 Task 展示模型）                   │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Repository: TaskRepository                                              │
│  - fetchAll() → TaskDao.getAll()                                         │
│  - add(TaskEntity) → TaskDao.insert() + NotificationService.schedule…    │
│  - update(TaskEntity) → TaskDao.update() + 取消/重排通知                   │
│  - delete(id) → NotificationService.cancel… + TaskDao.delete()           │
│  - toggle(id, value) → TaskDao.toggleCompleted() + 通知取消/重排           │
│  - clearAll() → NotificationService.cancelAll… + TaskDao.clearAll()       │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  DAO: TaskDao                                                            │
│  - insert/update/delete/query 使用 TaskEntity.toMap() / fromMap()         │
│  - 直接调用 DatabaseService.instance() 获取 Database                      │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Database: DatabaseService (sqflite)                                     │
│  - 单例，openDatabase('doable.db')，onCreate 建表 tasks                   │
└─────────────────────────────────────────────────────────────────────────┘
```

- **读**：UI 调用 `TaskRepository().fetchAll()` → `TaskDao.getAll()` → `db.query('tasks')` → `TaskEntity.fromMap(row)`，UI 再将 `TaskEntity` 转为本地 `Task`（如 HomePage）或直接用于编辑。
- **写**：UI 构造或修改 `TaskEntity`，调用 `TaskRepository` 的 `add`/`update`/`delete`/`toggle`/`clearAll`；Repository 先处理通知再调用 `TaskDao`；DAO 用 `entity.toMap()` 做 insert/update/delete。

---

## 3. TaskEntity 字段含义

| 字段 | 类型 | 含义 |
|------|------|------|
| **id** | `int?` | 主键，自增；插入时可为 null，插入后由 DAO 写回。 |
| **title** | `String` | 任务标题，必填。 |
| **description** | `String?` | 任务描述，可选。 |
| **time** | `String?` | 显示用时间，如 `"11:30 AM"`（`DateFormat('h:mm a')`）。 |
| **date** | `String?` | 显示用日期，如 `"26/11/24"`（`DateFormat('dd/MM/yy')`）。 |
| **hasNotification** | `bool` | 是否设置提醒；为 true 时由 NotificationService 在 date+time 调度本地通知。 |
| **repeatRule** | `String?` | 重复规则：`"Daily"` / `"Weekly"` / `"Monthly"`，或 `"Weekly:1,2,4"`（周几，1=Mon…7=Sun）。 |
| **completed** | `bool` | 是否已完成；用于列表排序（未完成在前）及筛选、完成时取消通知。 |
| **createdAt** | `String?` | 创建时间，ISO8601；表默认 `CURRENT_TIMESTAMP`。 |
| **updatedAt** | `String?` | 最后更新时间，ISO8601；DAO 在 insert/update 时写入。 |

---

## 4. 当前数据库 Schema

- **数据库名**：`doable.db`（由 `getDatabasesPath()` + `path.join` 得到路径）。
- **版本**：`_dbVersion = 1`。
- **唯一表**：`tasks`。

建表 SQL（`database_service.dart` 中 `onCreate`）：

```sql
CREATE TABLE tasks(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT,
  time TEXT,
  date TEXT,
  has_notification INTEGER NOT NULL DEFAULT 0,
  repeat_rule TEXT,
  completed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT
)
```

- 布尔在 SQLite 中存为 **0/1**（`has_notification`、`completed`）。
- 日期时间在应用层以 **TEXT** 存储（date/time 为显示格式，created_at/updated_at 为 ISO8601）。
- 当前 `onUpgrade` 为空，后续改表需在此做迁移并提高 `_dbVersion`。

---

## 5. 已使用的依赖包

| 依赖 | 用途 |
|------|------|
| **flutter** (SDK) | 框架与 UI。 |
| **cupertino_icons** ^1.0.2 | Cupertino 图标。 |
| **flutter_svg** ^2.0.10+1 | 加载 SVG（logo、filter、bell、calendar、clock、社交图标）。 |
| **sqflite** ^2.4.0+1 | SQLite 数据库（DatabaseService + TaskDao）。 |
| **path** | 拼接数据库文件路径（`p.join(base, _dbName)`）。 |
| **intl** ^0.20.2 | 日期时间格式化与解析（`DateFormat('dd/MM/yy')`、`'h:mm a'`）。 |
| **url_launcher** ^6.3.0 | 设置页打开外部链接（Twitter/GitHub/LinkedIn）。 |
| **shared_preferences** ^2.3.2 | 持久化“通知开关”等设置。 |
| **timezone** ^0.10.1 | 时区相关（被 awesome_notifications 使用）。 |
| **awesome_notifications** ^0.10.1 | 本地提醒的创建、取消、点击处理。 |
| **awesome_notifications_core** ^0.10.1 | awesome_notifications 核心。 |
| **awesome_notifications_fcm** ^0.10.1 | FCM 相关（若需云端推送可扩展）。 |

**dev_dependencies**：`flutter_test`、`flutter_lints` ^6.0.0、`flutter_launcher_icons` ^0.14.1、`build_runner` ^2.4.8。

---

以上即为基于当前代码的 Flutter TODO 应用结构、数据流、TaskEntity、数据库 schema 与依赖的 Markdown 分析摘要。