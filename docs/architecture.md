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
│   │   ├── UIVerification.swift      # 原生窗口检查与截图入口
│   │   └── ManagementVerification.swift # 隔离管理数据与原生操作检查
│   ├── Domain/Library.swift          # 模型、导航状态与异步仓储入口
│   ├── Domain/TargetCapabilities.swift # 可编辑能力与插入方式选择
│   ├── Domain/PreferencesValidation.swift # 快捷键索引与窗口几何验证
│   ├── Features/
│   │   ├── Theme.swift               # 材质、按钮、拖动与边缘缩放
│   │   ├── LauncherView.swift        # 分类、列表、页头与底部操作
│   │   ├── DetailDocument.swift      # 单容器分段详情、原生文本选择
│   │   ├── DesignUI.swift            # Figma 资源、面板、分段控件与文本
│   │   ├── ManagementWindow.swift    # 管理导航、列表、预览与保存协调
│   │   ├── ManagementGrid.swift      # 摘要卡片集合、按 ID 打开与滚动恢复
│   │   ├── PromptEditor.swift        # 独立字段与本地草稿编辑
│   │   ├── UsageDashboard.swift      # 真实本地计次、趋势与排行
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

`LauncherView` 负责三级导航与状态反馈；`DetailDocument` 以「Prompt / 经验与来源」切换，后一段仍将原始经验、来源与解释分开。正文是只读、可选的 `NSTextView`，独立滚动；围栏代码使用系统等宽字体，其余正文使用系统比例字体。复制完整 Prompt 使用原始字段，不使用排版后的文本。

`PromptLibrary` 将 repository 操作派发到专用串行后台队列，再把结果回传主线程。`SQLitePromptRepository` 首次访问时打开本地库，在 `BEGIN IMMEDIATE` 事务内检查 schema version、建表并导入原有七条示例；commit 后才可见。重启不重复导入，也不自动覆盖已有修改/删除。分类独立查询 categories；第二层的 `PromptSummary` 不含正文；第三层通过 ID 与分类 ID 精确查询完整 `PromptEntry`。没有数据库错误时静默回退 JSON 的路径。

UI 通过请求代次丢弃迟到结果，加载期间禁止插入旧详情，返回保留选择/滚动。失败显示简短反馈，下次唤起重试失败的读取。窗口动画和系统插入流程保留，视觉按最新 Figma 更新。SQLite 操作使用参数绑定、外键、版本门禁和超时，日志仅记录层级、行数、错误代码和耗时。首次种子数据保留稳定 ID 与原文字段。

`ManagementWindowController` 复用同一 `PromptLibrary`，提供列表、预览、标题／简述查询及 `PromptEditorView`；长文本使用可撤销的原生 `NSTextView`。管理窗口为 titled/fullSizeContentView 原生窗口，保留红黄绿系统按钮，并通过 fullScreenPrimary 进入独立 Space。打开管理窗口时切换 regular 应用身份，显式设置自家 AppIcon；Dock 重开返回管理窗口。关闭通过 delegate 保存草稿后隐藏。创建／编辑在事务中验证必填和分类；重试使用原 UUID，编辑对比原快照拒绝过期覆盖。成功提交后发送通知，管理页与浮窗重新查询，按 ID 保留有效选择。

伴随 `library-activity.sqlite3` 通过同一串行连接按需 ATTACH，保存编辑草稿和成功使用事件；主内容 schema 仍为 v1。自动草稿、切页、关闭及退出均保留未完成输入，失败不关闭表单。退出先取消当前终止请求，完成草稿和队列排空后再次终止，避免 terminateLater 的 MainActor 回调死锁。`UsageDashboard` 只聚合实际成功复制及完整回读确认插入的事件，内部粘贴不重复计次。

V7 管理页默认使用 `NSCollectionView` 摘要网格，只读取标题、简述、分类及来源；点选稳定 ID 后才查正文。网格和阅读列表共享精确分类＋搜索查询与代次防护。原位 `PromptEditorView` 挂在同一详情容器，保存后保持有效筛选、选择与滚动。返回网格不再重新读取正文。窗口缩放先更新详情容器，再布局编辑器与其底部动作，避免最小尺寸使用上一帧宽度。

`ExperienceView` 将现有 `ExperienceController` 的候选、建议及确认直接绑定到右侧嵌入编辑器。查看条目不创建候选，文字变化才更新；先写入最新候选再触发取消回调，防止同步回调重建旧编辑器并丢失焦点。Checkbox 仅控制生成子集，保存只接受 confirmed 集合。部分保存后列表、分母、当前 ID 和草稿共同来自剩余 session，全部保存显示完成状态。`manualEntry` 是可选 JSON 字段，旧草稿缺省沿用 manualPrompt 的旧判断；切换录入方式只改该标记，保留原文和已贴 Prompt。没有 SQLite schema 迁移或新网络接口。


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

Stage 2 当前开发版已接入独立管理窗口、事务新增／编辑、管理页搜索、草稿与使用统计。完整验收状态见 [figma-integration.md](figma-integration.md)。JSON 导入导出、删除和浮窗搜索尚未实现；不把测试中的 JSON 字段往返当成产品导入导出功能。

Stage 3 改为客户端直连 DeepSeek：`PromptGenerating` / `DeepSeekClient` 用 URLSession 异步请求，Keychain 保存凭证，不设中转。点击整理先经 PromptLibrary 串行队列保存 EditorDraft，再读取当前分类并发请求。JSON 模式加本地字段、长度、分类互斥与 ID 校验；来源和原文不在返回结构中，不能被模型回写。网络响应、凭证、正文和来源都不记日志。

EditorDraft 在原 JSON payload 增加可选 newCategoryName 与 candidate，旧草稿仍能解码。请求绑定 operationID、编辑器实例和快照；编辑、切页、取消、保存、关闭、退出使请求失效。只匹配当前请求的响应可存候选，采用候选是显式操作，原文和来源保持原样。原有手工编辑和候选一起存伴随库，退出继续排空队列。

分类直接读 categories 表；PromptCategory.initial 只负责种子和隔离内存夹具。新增分类在条目保存事务内去重并分配 UUID，沿用 v1 表结构；同事务失败不会遗留分类。管理侧栏可滚动；编辑菜单、浮窗、历史使用校验、图表系列、图例和分布都使用数据库分类。分类显示按数据库顺序循环现有五色，侧栏、详情、编辑、浮窗及统计共享完整分类列表，复用五种柔光圆点；新增分类保持 folder 符号，无新资源或颜色字段。

Stage 4 才增加 PostgreSQL、版本、删除标记与同步游标。成功刷新后原子切换缓存，冲突和失败明确反馈。计划目录不等于已创建服务。

## 验证

构建与单元测试命令见 [README](../README.md)。单元测试覆盖导航记忆、示例 ID/字段完整性、围栏代码字体、UTF-16 范围和剪贴板所有权/恢复；SQLite 临时库测试覆盖重启、事务、分层和故障；自动化不能替代真实跨应用插入或性能验收。完整入口见 [testing.md](testing.md)。运行检查、用户实测与限制统一见 [prototype.md](prototype.md)。

## v0.4 经验会话与批量整理

`ExperienceSession` 保存整篇原文、来源、版本号、当前条目及每条稳定 ID、原句、独立消息／未发送输入、勾选和候选。`ExperienceController` 在 MainActor 调度 UI，网络／编码／解析由非隔离的 DeepSeekClient 异步执行，SQLite 继续通过 PromptLibrary 串行队列。识别、讨论与整理各有系统提示词；讨论和整理携带完整原文背景保留全局条件，聊天历史仅来自当前条。LLM 无本机操作工具，Fetch 是客户端控制的 DeepSeek 读取接口。

新会话草稿与按版本存档在伴随库的 experience_drafts / experience_archives；旧 editor_drafts 和 usage_events 保留，正式内容 schema 仍为 v1。批量保存复用 writeDraft，在同一个事务内去重新分类、写入选定 Prompt、存档原文／讨论并保留未选草稿；只有 commit 后通知。存档版本阻止迟到自动保存复活已保存批次。删除比较完整旧快照，提交后刷新管理与浮窗，历史事件与分类保留。

当前分类色扩为十五种，由 Theme.categoryColor 和 DesignAssets.categoryDot 统一按完整数据库顺序映射；前五色不变，第16回第1。原生新增 ExperienceView 双栏，审核复用 PromptEditorView 的 reviewMode，原文使用既有只读 TextDocument。已有手工草稿继续使用原编辑器，不静默迁移丢失手改。具体流程、提示词、验证入口和恢复方法见 [experience-dialogue.md](experience-dialogue.md)。

## v0.5 一键整理与独立 Prompt

V6 替代上述 v0.4 聊天入口。ExperienceController 的选择、粘贴和审核均不调用模型；v0.5.1 的 send 仅识别初始原文／链接，单／多条统一由 generateSelected 明确生成。请求前落盘，使用最新分类；operationID、候选快照与取消状态防止迟到覆盖。切换查看不取消另一条的生成。旧消息／未发送输入仅保留为历史数据，新生成不传 discussion。

ExperienceSession 的可选 manualPrompt 保存未进入审核的手贴内容，兼容旧 JSON；进入审核后使用每条 candidate.prompt，退出排空包括原文为空的手贴草稿。生成 JSON 仍严格校验六字段与分类；保存时仅允许简述／解释为空，其他字段、长度、分类与事务校验继续执行。审核在 PromptEditorView 内左列表／右编辑，切换先 stashReview。

## v0.5.1 管理交互修复

分类＋搜索继续复用 SQLite 的 category_id 精确 AND 查询，不改 SQL。ManagementWindow 在新请求发出时清空旧卡片与详情，queryGeneration 和当前页面共同拒绝迟到结果；计数来自当前结果。

CategoryPopover 复用于正式编辑器和候选编辑器，使用 transient NSPopover、原生表格键盘和字段旁新建表单。同名名称直接选已有 ID；新名称暂存 EditorDraft，正式提交时由 writeDraft 事务去重并创建，失败不留下孤立分类。详情删除采用紧凑 NSAlert，安全操作默认焦点。

ExperienceItem 新增可选 confirmed 和 suggestion，仅扩展伴随库 JSON，不改 schema。selected 只控制批量生成；candidate 代表生成／手贴结果；confirmed 代表人工确认，任何候选修改使其失效。已有 Prompt 的新生成结果存 suggestion，明确采用且快照匹配才替换。旧 JSON 缺少 confirmed 时继续待确认。审核集合保留空 Prompt，列表按稳定 ID 切换，字段验证阻止空值确认。saveExperiences 只提交 confirmed，事务内归档并写 remaining；当前 ID 有效则保留，已保存条目移除，分母来自剩余数组。
