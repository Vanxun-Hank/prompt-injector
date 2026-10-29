# 架构与数据流

当前是 Swift Package Manager 可运行客户端，所有界面使用 AppKit。以下区分已有代码和后续阶段，不预建空服务。

## 当前目录

```text
Package.swift
scripts/build-app.sh                 # 构建、版本指纹、打包 .app、开发证书签名
scripts/read-logs.py                 # 读取轮转日志、关联单次插入与捕获
macOS/
├── PromptInjector/
│   ├── main.swift
│   ├── App/
│   │   ├── AppDelegate.swift         # 菜单栏、全局快捷键、外部应用记录
│   │   ├── LauncherWindow.swift      # 窗口、键盘路由、几何与插入协调
│   │   ├── PanelPresentation.swift   # 浮窗出现/隐藏与中断控制
│   │   └── UIVerification.swift      # 原生窗口检查与截图入口
│   ├── Domain/Library.swift          # 模型、导航状态与异步仓储入口
│   ├── Domain/TargetCapabilities.swift # 可编辑能力与插入方式选择
│   ├── Domain/PreferencesValidation.swift # 快捷键索引与窗口几何验证
│   ├── Features/
│   │   ├── Theme.swift               # 材质、按钮、拖动与边缘缩放
│   │   ├── LauncherView.swift        # 分类、列表、页头与底部操作
│   │   ├── DetailDocument.swift      # 单容器分段详情、原生文本选择
│   │   └── PageTransition.swift      # 内容视口方向性过渡与快照清理
│   ├── Services/
│   │   ├── SQLitePromptRepository.swift # 事务建库、参数化分层查询与错误日志
│   │   ├── InjectionService.swift    # 目标捕获、单次插入与全文确认
│   │   ├── InsertionPlan.swift       # UTF-16 选区和预期文本
│   │   ├── PasteboardTransaction.swift # 所有权检查与剪贴板恢复
│   │   ├── DiagnosticLog.swift       # 类型化元数据、版本、串行写入与轮转
│   │   ├── InsertionPreflight.swift  # 当前权限与旧捕获状态协调
│   │   └── AccessibilityAccess.swift # 当前进程权限检查和系统入口
│   └── Resources/prompts.json        # 七条项目内置示例
└── PromptInjectorTests/              # 导航、排版、插入、配置与日志回归
```

## 当前边界

`AppDelegate` 使用 Carbon 注册全局快捷键，跟踪最近外部应用。默认 `⇧⌥Space`，可选 `⌃⇧Space`。先注册新键，成功后注销旧键；失败保留原注册。切换依据窗口是否可见，而非是否拥有焦点。

`LauncherWindowController` 管理单个浮窗。显示前捕获外部输入目标；隐藏时记忆当前页的选择和滚动。`UserDefaults` 保存尺寸、位置与快捷键；`NavigationState` 只在当前进程保存分页面选择和滚动。

`PanelPresentation` 负责显示/隐藏动效与中断代次；以逻辑呈现状态驱动快捷开关，避免关闭动画期间误判可见性。窗口 frame 不参与动效；关闭回调必须匹配当前代次。插入路径跳过显示/隐藏动效。

`PageTransition` 仅处理共享内容视口：依据层级决定方向，旧页以本应用透明内容快照短暂淡出，新页以轻微位移淡入。快照不参与命中或辅助功能树；中断、缩放、隐藏和结束都会清理，不影响真实页的选择、滚动或键盘响应。

`LauncherView` 负责三级导航与状态反馈；`DetailDocument` 将原始经验、来源、解释、Prompt 展示为一个容器中的四段。正文是只读、可选的 `NSTextView`；围栏代码使用系统等宽字体，其余正文使用系统比例字体。复制完整 Prompt 使用原始字段，不使用排版后的文本。

`PromptLibrary` 将 repository 操作派发到专用串行后台队列，再把结果回传主线程。`SQLitePromptRepository` 首次访问时打开本地库，在 `BEGIN IMMEDIATE` 事务内检查 schema version、建表并导入原有七条示例；commit 后才可见。重启不重复导入，也不自动覆盖已有修改/删除。分类独立查询 categories；第二层的 `PromptSummary` 不含正文；第三层通过 ID 与分类 ID 精确查询完整 `PromptEntry`。没有数据库错误时静默回退 JSON 的路径。

UI 通过请求代次丢弃迟到结果，加载期间禁止插入旧详情，返回保留选择/滚动。失败显示简短反馈，下次唤起重试失败的读取。原有样式、窗口动画和系统插入流程保留。SQLite 操作使用参数绑定、外键、版本门禁和超时，日志仅记录层级、行数、错误代码和耗时。首次种子数据保留稳定 ID 与原文字段；后续编辑/导入仍属 Stage 2。


## 插入路径与限制

显示前记录外部应用、辅助功能焦点元素、文本及 UTF-16 选区 → 插入时检查权限并等待快捷键松开 → 校验原文本与选区 → 隐藏浮窗并激活原应用 → 再次确认原元素仍获焦点、文本和选区未变化 → 执行一次插入 → 最多等待 1.2 秒回读确认全文。

用户实测发现 Codex 的 `AXSelectedText` 写入调用成功但输入框仍空白，因此 `com.openai.codex` 改用标准粘贴作为主路径，不在直接写入之后叠加重试。`PasteboardTransaction` 暂存剪贴板全部可读取条目和类型，写入纯文本，再只向目标 PID 投递 V 的按下/抬起事件（按下带 Command 修饰），不投递 Return。其他应用保留直接辅助功能路径，尚不宣称兼容。

`InsertionPlan` 验证 UTF-16 选区，拒绝拆断 surrogate pair 或越界范围，并构造精确预期文本。回读仅统一 CR/LF 换行差异，不接受前缀或裁去正文。只有确认完整结果才恢复剪贴板，且 changeCount 和当前值仍属于本次操作时才恢复；用户后来复制的内容不会被覆盖。超时不自动再粘贴，保留当前剪贴板以避免和迟到的粘贴请求竞争，并提示检查原输入框。

`insertion.lastResult` 仅记录阶段、方法、UTF-16 长度、角色、能力布尔值和时间，不保存输入框原文或 Prompt。这些元数据不单独等于成功验收；2026-10-29 已结合用户亲手操作确认完整插入、不发送以及程序全文回读一致，完成当前 Codex 核心路径验收。

`DiagnosticLog` 另存完整事件历史，每次捕获有 captureID、每次插入有 operationID，并包含构建 ID 与源码指纹。捕获早退、插入异常也更新最后状态，避免旧成功残留。获权后若仍持有未授权时的捕获失败，要求重新唤起以捕获真实输入框。日志在后台串行写入，文件锁协调多进程轮转，写盘失败不抛进业务流程。数据边界与读取命令见 [debugging.md](debugging.md)。

`AccessibilityAccess` 在实际应用进程内检查权限，在启动、激活、捕获和插入时记录仅含授权布尔值、程序路径、PID 与时间的状态。权限入口调用系统标准请求 API，不修改 TCC 数据库或替用户授予权限。`accessibility.permissionSnapshot` 反映最近一次检查，不是持续轮询状态。

用户开启系统开关后，旧临时签名构建仍报告未授权。构建已改用本机已有开发证书来保持稳定身份；用户重新添加最终签名版本后，应用进程已确认授权生效。当前 Codex 核心插入已实测；其他应用与全部异常路径仍需分别验证。

## 后续持久化与服务

Stage 1 已用 SQLite repository 取代示例加载器：分类查询不读条目正文，列表查询只取标题与简述，进入详情才读取完整字段。UI 不直接拼 SQL；数据工作避免阻塞主线程。种子迁移保留现有 ID，并继续明确示例属性。

Stage 2 增加独立管理窗口、事务保存和 JSON 导入导出；保存成功发内容变更事件，刷新当前列表并保持选择。扩展作者/来源链接与创建/修改时间，保留原文与 Prompt 的独立字段。

Stage 3 增加本地 Draft 和 Go + chi 整理接口。原文先持久化，手工编辑稿和生成候选分开保存，由用户选择采用候选。

Stage 4 才增加 PostgreSQL、版本、删除标记与同步游标。成功刷新后原子切换缓存，冲突和失败明确反馈。计划目录不等于已创建服务。

## 验证

构建与单元测试命令见 [README](../README.md)。单元测试覆盖导航记忆、示例 ID/字段完整性、围栏代码字体、UTF-16 范围和剪贴板所有权/恢复；SQLite 临时库测试覆盖重启、事务、分层和故障；自动化不能替代真实跨应用插入或性能验收。完整入口见 [testing.md](testing.md)。运行检查、用户实测与限制统一见 [prototype.md](prototype.md)。
