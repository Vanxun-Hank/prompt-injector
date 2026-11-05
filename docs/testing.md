# 客户端回归测试套件

## 2026-11-06 · 工作台连续处理 / v0.6.1 · 最新

完整 `python3 scripts/test-suite.py` 通过 **130 Swift、11 Python、219 原生检查、45 张 PNG**。最终报告 `artifacts/tests/20261105T165642.770128Z/summary.json`，审查包 `build/Workbench-Continuity-Review/Prompt Injector.app`，build `20261105T165652Z`。覆盖 20→17、运行和排队移除、两篇来源与生成上下文、失败/取消/重开、完成和部分保存、三种入口的详情图标与三个 Tab 的完整复制。真实鼠标键盘使用隔离夹具；系统插入与真实模型未复验。失败复现、实际安装、快照及回滚见 [连续处理](workbench-continuity.md)。

## 2026-11-04 · V7 完整移植 / v0.6.0 · 历史

自运行 `python3 scripts/verify-management-v7.py` 实际执行约定的 `python3 scripts/test-suite.py`，通过 **125 Swift、10 Python、199 原生检查、43 张 PNG**。报告 `artifacts/tests/20261104T041850.632250Z/summary.json`；隔离包 `build/Management-V7-Review/Prompt Injector.app`，build `20261104T041900Z`，指纹 `9c54dd763ca0a67d10dc8e15d1d8f4a990911aa8623292d482c9e1d7cd0fe264`。运行时所有截图首次成功；前次截图失败报告保留，没有用旧图补过。

新增 ManagementV7Tests 覆盖摘要网格、原位编辑筛选和滚动、单／五／二十条模拟生成确认后部分保存重开、手改取消与迟到响应、录入方式往返恢复及候选显式采用。原生追加默认／最小网格、内嵌编辑布局、字段就地错误和剩余0／4／19；套件自身拒绝缺失V7检查或截图。修改前后的布局与运行限制见 [完整记录](management-v7-implementation.md)。

本轮没有请求真实 DeepSeek、真实 Codex 插入或物理断网，保留历史验收范围；VoiceOver、系统 Reduce Motion 和最低macOS兼容性未重验。不将模拟、路由和截图宣称为系统插入成功。安装后两库的比对与恢复位置见完整记录。

独立完整原生复核 ship；第一次截图裁切判 recapture，未当通过使用，修复验证窗口放置后全量重跑。随后安装同一包并实际打开，PID71851／build20261104T041900Z与常用路径一致；原3条草稿恢复，两库规范化摘要不变。旧包及两库备份 `~/Library/Application Support/Prompt Injector/Backups/before-v060-20261104T041802Z/`，证据 `artifacts/installation/v060/report.json`。

## 2026-11-04 · 管理 UI 修复 / v0.5.1 · 历史

完整运行 `python3 scripts/test-suite.py`：**119 Swift、9 Python、165 原生检查、36 张 PNG** 通过。最终报告 `artifacts/tests/20261104T032656.681208Z/summary.json`；审查包 `build/Management-Fixes-Review/Prompt Injector.app`，build `20261104T032707Z`，source `3bd744da77a239d24cd1f86bc183cfef29a40180ebaf6ef9f6607960456bf546`，版本0.5.1。完整测试在隔离临时库运行，不修改正式数据。

新增分类ID＋搜索AND、快速切换清空与迟到查询；分类Popover空名、规范化重名、待建名称；Unicode差异高亮；旧JSON不把批量勾选当确认；1／5／20条顺序模拟生成、确认1条、部分保存、剩余计数／当前ID／来源和新repository读取；保留／采用建议及后来的手改保护。审核清空Prompt再切条的独立回归先失败5断言，修复后通过。保留既有故障回滚、草稿恢复、分类扩展、统计、浮窗立即加载和插入路由检查。

原生检查增加确认按钮真实可见、分类空名就地错误、删除取消默认与实际sheet可见；截图覆盖轻量新增分类、删除、并排比较及默认／最小审核。窗口捕获包含sheet，不能用单独sheet黑图作为视觉证据；最终36图已人工查看相关页面。复制与插入路由使用既有模拟目标，未重复真实Codex填写。

Figma 网页实际点击验证：编码3条、编码AND「测试」1条；分类上下键/Enter、Escape、点外部关闭；同Popover新建与创建后自动选择；更多→居中删除→取消回原详情。Figma字段输入、API和保存仍是预设样例；新建空名／重名／失败单独示例页不是网络失败实测。设计修复前备份页408:1124，详见 management-ui-fixes.md。

独立原生复核初判 fix（PI-028），修复后仅针对该项判 resolved；不扩大为全部系统重验。真实 DeepSeek、物理断网、真实跨应用插入、VoiceOver、系统 Reduce Motion 和最低macOS本轮未测。生成失败、取消、重试、迟到响应由控制器／模拟服务回归覆盖。

同一签名包已安装并实际打开，PID50476／build20261104T032707Z与常用路径相符。更新前无App实例；备份旧App与两库到 `~/Library/Application Support/Prompt Injector/Backups/before-v051-20261104T033121Z/`。安装后表摘要未变；恢复3条草稿后只有payload的JSON键顺序变化，解码值、revision、原文、候选及勾选逐项相同，规范化两库摘要一致。实际正式内容仍0、分类7、使用事件5、经验草稿1，不恢复早期内容。报告 `artifacts/installation/v051/report.json`。

## 2026-11-04 · V6 / v0.5.0 · 历史

通过 `python3 scripts/verify-experience.py` 自运行入口实际运行 `python3 scripts/test-suite.py`：**111 Swift、9 Python、157 原生检查、33 张 PNG** 全部通过。最终报告 `artifacts/tests/20261103T163827.630468Z/summary.json`，包装报告 `artifacts/experience-verification/20261103T163827.570925Z/report.json`。测试包 `build/Management-V6-Review/Prompt Injector.app`，build `20261103T163837Z`，源码指纹 `d94a2d15362f0e4767628abbd9e57aeeebdde63d5ffab28f67ac5a084cf84ca4`，版本 0.5.0。

新增真实控制器／SQLite 回归：选择和粘贴不发网络、每条 Prompt 切换及重开保留；单条一键识别／生成后审核；最新分类、重新生成确认拒绝、超时重试、手改取消及迟到响应；零勾选／空 Prompt 阻止审核；旧 JSON 草稿与五百条历史消息保留；手动粘贴的简述／解释可空，API 解码仍严格完整。退出前仅有 Prompt 的草稿立即排空并从新 repository 读取，覆盖 PI-026。

原生夹具通过默认／最小原文与 Prompt、并排手动录入、审核列表切换保留修改、右侧字段／新分类可见、原文和来源只读、批量事务保存、第六类、保存后浮窗立即加载、注入取消／确认删除。删除确认分支使用测试注入，不代表真实 NSAlert 实点。既有键盘插入路由和本地使用统计测试保留；这些不能替代真实跨应用填写。

独立复核首次返回 fix，Prompt-only 退出、审核布局与来源 placeholder 三项已修复；第二轮仅对三项评分 resolved / ship，不声称全系统重审。默认套件为模拟 HTTP／fixture、临时数据；本轮未请求真实 DeepSeek、未做物理断网、真实 Codex 插入、系统 Reduce Motion／VoiceOver 或最低 macOS 验收。`--live-api` 保留为显式真实请求入口，已移除聊天步骤。

同一通过包已备份后安装到常用路径并实际打开，PID 30927 路径与 build 相符。签名验证及逐文件摘要一致。安装前主库实际为 0 条内容／7 分类，伴随库为 5 使用记录／0 旧编辑草稿／1 经验草稿；打开后内容、分类和使用历史摘要不变。CUA 报告用户同时操作窗口，经验草稿 revision/currentID/items 后续发生变化，因此不声称草稿字节不变；草稿数仍 1，原有三条候选在新版恢复，未回填较早的 28 条备份。证据 `artifacts/installation/v050/report.json`、`installed-app.png`。

本轮旧 App／两库备份：`~/Library/Application Support/Prompt Injector/Backups/before-v050-20261103T163945Z/`。恢复 App 只回退代码；恢复内容需先退出所有实例、另存当前状态，再成对恢复两库。Keychain 未改；旧版不能显示 V6 的 Prompt-only 未完成草稿，回退前先在新版完成或保留双库备份。

## 2026-11-03 · 拆分边界补丁（未安装）

完整 `python3 scripts/test-suite.py` 通过 **108 Swift、9 Python、147 原生检查、29 张截图**。报告 `artifacts/tests/20261103T124106.411928Z/summary.json`；审查包 `build/Boundary-Review/Prompt Injector.app`，构建 `20261103T124113Z`，指纹 `2e50be07d384ffd15670d58620174a2b66917270173ad605344f001c2d6d8402`。

先失败后修复的回归覆盖一段不拆句、完整条件、二十个顶层编号、重复18续写、缩进子步骤、段落合并／漏段／重叠／重排、直接以1开头的单行列表（含尾换行和换行前言）、第100条，以及识别失败后草稿／来源重开与重试。独立代码复核初次要求修正后两项，第二次只对两项修复评分resolved／ship。源码中的 identify 请求携带实际 sourceUnits／numbered，HTTP夹具断言这些字段，不只检查提示词字符串。

本轮没有真实API、跨应用插入、物理断网或安装验证，正式库与Keychain未改。V6为另行制作的Figma原型，九张指定截图视觉复核为可交用户审阅；网页版点通预设选择／审核／分类／保存／删除，与本次原生旧UI回归分开。详情见 [content-management-v6.md](content-management-v6.md)。

## 2026-11-03 · 经验讨论 V5 / v0.4.0

最终完整 `python3 scripts/test-suite.py`（由新脚本 `verify-experience.py` 调用）通过 **102 Swift、9 Python、147 原生检查、29 张截图**。报告 `artifacts/tests/20261102T162434.250338Z/summary.json`，构建 `20261102T162441Z`，源码指纹 `d304150aced6f34ef18b938bcafcd57b7e74a97931ecc6cbb9554ab1f36d0da9`。新增实际加号／发送／文字讨论／方框独立点击、每轮分隔、最小双栏、原文只读、候选手改、批量保存和浮窗加载、取消／确认删除等检查。模拟服务全部只在隔离库和显式验证路径使用，不作为真实模型结果。

同一构建真实验证 `artifacts/experience-verification/20261102T162434.202069Z/report.json`：实际 Fetch 用户给的 X 链接，识别20条，选前2条完成多轮讨论、结构化整理、候选编辑、临时 SQLite 保存与重开；其余18条保留在隔离草稿。`realAPI`、`fetchVerified`、`realMultiRound` 均为 true，`formalLibraryChanged` 与 `realCodexInsertion` 为 false。只验证这一个公开链接与两条候选，不承诺任意网页或模型语义普遍正确。

开发回归保留：中断恢复版本冲突、首聊覆盖未发送输入、500条消息越界后无法保存、X回复混入及多行正文截断、审核原文空白与来源裁切。首聊／上限／多行三项在修复前3测试11断言失败，修复后通过，独立审查随后仅对这批修复判 resolved/ship；四张原生布局截图可交付。每条讨论与整理还传入完整原文背景，HTTP 断言验证全局条件可见。

已把同一验证包更新到常用 Build 启动位置并实际打开新增经验双栏；运行 PID／版本／签名／逐文件摘要一致，记录 `artifacts/installation/v040/report.json`。更新前正常退出并备份旧包与两库；启动后逐字段核对旧用户表不变：28条、7分类、5使用事件、0旧编辑草稿。新增两张会话表仅是伴随库扩展，正式 schema 仍为v1。

本轮未复测真实 Codex 跨应用插入、物理断网、真实系统权限拒绝与目标失效；既有逻辑回归通过不替代这些人工验收。用户可运行 `python3 scripts/verify-experience.py`；真实调用需显式加 `--live-api`，具体命令、限制和代码／数据恢复见 [experience-dialogue.md](experience-dialogue.md)。

## 2026-11-01 · 阅读 V2 / v0.3.1

最终完整套件 `artifacts/tests/20261101T044433.502881Z/summary.json`：87 Swift、8 Python、129 原生检查、25 张 PNG 全通过。隔离审查包为 `build/Reading-V2-Review/Prompt Injector.app`，build ID `20261101T044439Z`，源码指纹 `07bdfd40b46de6b8de4d2423208c3d8e6b25f9777ce0857ade4f1b2228d464bd`。完整运行使用 PROMPT_INJECTOR_APP_OUTPUT 指向此独立目录，未覆盖原 Final-Review 包。

新增检查：三页正文逐字一致、来源链接、说明分页仍复制完整 Prompt、长标题与最小窗口动作不重叠、五色循环和同资源圆点、26 分类独立滚动、一次失败后新增分类再重试能读到最新 ID，以及模型建议同名新类归回稳定 ID。原生新增原文／说明／分类滚动三张图，套件校验器同步要求这些证据。已有编辑、草稿、迟到响应、历史使用与插入路由检查保留。26 分类是 UI 隔离夹具，正式库未添加这些分类。

真实 API：`artifacts/llm-real/reading-v2-category-reuse/report.json`，公开的第 3 条经验、现有 7 分类快照，返回已有「模型选择」ID `583102BD-93BA-4BE9-B375-2097705635E4`，未建议新分类；候选编辑、原文／来源保真、隔离 SQLite 保存与重开均通过。该报告 build `20261101T044251Z`，与最终包的客户端代码相同，之后仅统一版本号至 0.3.1；不会写成最终构建再次请求。标题「优先选用业界最佳模型」（10 字，不含验收编辑后缀）、简述「在任务需要模型且模型可选时使用。」；语义仍需人工审核，一条样本不保证所有近义分类都能正确合并。

真实桌面：正常退出旧包后，打开 v0.3.1 内容管理；正式库仍为 28 条／7 类，并与请求前隔离快照逐字段比对条目和分类不变（artifacts/reading-v2/formal-data-check.json），第六黄、第七蓝，实际点击作者原文页显示用户提供的第 8 条原句及原来源。当前画面 `artifacts/reading-v2/app-live.png`；独立 finish review 对本轮 diff、默认／最小窗口及三态图判定 ship。旧条目标题／简述不批量改写。

本轮未重新验证真实 Codex 跨应用插入、物理断网及真实权限拒绝／目标失效；模拟路由不替代这些验收。没有 UI 导入导出功能，未声称产品导出往返通过。

回滚：本轮未改 schema、未写正式内容。恢复 v0.3.0 审查包即可回退 UI／生成指导（须先正常退出当前包）；代码可撤销本轮对应提交或在独立 worktree 使用 `3ba1bf2`，不覆盖已有未提交编辑。数据无需因本次 UI 回滚而恢复；若另行恢复用户资料，退出所有实例，先备份当前状态，再成对恢复 library.sqlite3 与 library-activity.sqlite3。Keychain 独立保留，代码或数据库回滚均不改变 key。


每次代码或行为修改、每个 Stage 交付前，运行同一个入口：

```sh
python3 scripts/test-suite.py
```

顺序是 Swift 测试 → Python 工具测试 → 打包及签名验证 → 真实 AppKit 窗口检查与截图。每次结果独立保存在 `artifacts/tests/<UTC时间>/`，含各步骤日志、summary.json、原生检查报告和 PNG。任何步骤失败、报告缺项、截图缺失或构建信息不匹配都返回非零退出码。只有完整通过，才把本轮 UI 报告与截图复制到 `artifacts/ui/`。

需要解锁 macOS 桌面并允许截图；锁屏时不宣称通过 UI 验收。无桌面环境可运行 `python3 scripts/test-suite.py --headless`，结果明确标记为部分检查，不能替代完整套件。未通过时按 debugging.md 检查日志、最小复现、修复和重跑；不要删除断言或扩大超时来掩盖产品错误。

## 自动化案例

| 范围 | 测试入口与断言 |
| --- | --- |
| SQLite 初始化与重启 | `SQLiteRepositoryTests`：首次事务建库、稳定 ID/所有字段往返、重启不读取种子、不重复、不覆盖修改、不复活删除 |
| 分层读取 | SQLite column authorizer 禁止读取正文列，分类和列表仍成功，详情必须读取正文；不是仅检查 SQL 字符串 |
| 数据边界 | 中文、emoji、多行、引号、NUL 精确保留，参数绑定、错误分类隔离、空列表/缺失条目 |
| 迁移与故障 | 无效种子回滚、再次打开可恢复、损坏/较新版本不覆盖、查询失败记录元数据、并发首次打开无重复 |
| 异步页面 | `LibraryLoadingTests`：仓储不在主线程执行，迟到详情不覆盖新页面，失败不保留可插入的旧 Prompt，重试恢复，选择记忆，原样传递插入内容 |
| 系统插入逻辑 | `InsertionTests`、`BugRegressionTests`：Codex 选粘贴路径、完整回读判定、UTF-16 选区、剪贴板所有权、权限变化、旧成功状态与非法配置 |
| 导航与排版 | `NavigationTests`：独立滚动/选择记忆、种子内容完整、只有代码段等宽字体 |
| 日志 | `DiagnosticLogTests`：跨操作历史、轮转、并发、写入失败隔离；Python 查看工具过滤与不完整行 |
| 原生窗口 | `UIVerification.swift`：三级页面的三种尺寸、复制、键盘/IME 保护、滚动、长内容、固定操作栏、⌘Return 传递当前完整 Prompt/普通 Return 不插入、几何恢复、窗口及页面动画、中断、减少动态效果 |
| 套件自身 | `test_suite_report.py`：顶层 passed 不能掩盖动画失败，缺失截图/空报告不能算通过 |
| 管理与持久化 | `ManagementTests`：创建／重试／重开、编辑分类与过期覆盖、失败事务保留草稿、字面量搜索、事件计次、主库 schema v1 兼容、提交后通知和退出排空 |
| 管理原生窗口 | `ManagementVerification.swift`：新增／编辑、保存失败输入保留、取消恢复草稿、搜索、复制、真实计次及最小尺寸；新增 6 张管理截图，整套要求 22 张截图和至少 85 项检查（新增候选、新分类编辑与第六类统计） |

管理原生验证还检查三枚系统窗口按钮，并实际执行最小化／还原、放大和关闭；统计用真实列矩形验证最右列可见。插入错误状态同时检查按钮禁用与 ⌘Return 不路由，测试重置有效捕获后再恢复路由；这不替代真实外部输入框验收。

进程级退出回归以临时 SQLite 调用 `--verify-termination`，不创建窗口、不注册快捷键、不捕获外部目标；验证 MainActor Task 中退出不死锁，且排队的使用记录已落盘。

单元测试使用临时数据库，UI 验证也使用独立临时 SQLite，不读取或覆盖用户资料库。UI 模式不注册全局快捷键、不捕获外部目标。真实应用保存路径为 `~/Library/Application Support/Prompt Injector/library.sqlite3`，只在首次初始化时读取打包 JSON；现有库出现错误不会删除重建或自动回退 JSON。

## 持续保留的人工系统回归案例

1. 点击 Codex 输入框 → ⇧⌥Space → 选择条目 → ⌘Return，完整插入且不发送（当前 Stage 1 已实测通过；后续行为改动仍需按需发布复核）。
2. 已显示时再次按全局快捷键，浮窗隐藏；切换后仍保留选择。
3. 权限缺失或捕获后目标失效时不向其他输入框写入，复制仍可用。
4. 断网后完成真实 Codex 调用；自动化只证明仓储和调用代码无网络依赖，不替代物理断网验收。
5. 中文输入法真实候选窗、拖动边角、多个显示器和最低 macOS 版本。

不使用测试模拟替代上述系统验收。已建立带样本量的内存、空闲 CPU、热唤起性能基线，见 [stage1-acceptance.md](stage1-acceptance.md)；SQLite 查询日志耗时不是端到端唤起延迟。

## 本次验证基线

2026-10-29：29 项 Swift、4 项 Python、67 项原生窗口检查通过。基线报告为 本地该轮 `artifacts/tests/` 报告（不公开），构建 `20261029T063641Z`。后续以每次套件产生的独立报告为准，不以这里的历史计数推断通过。

2026-10-30 最终基线：36 Swift + 6 Python + 69 原生检查通过，本地该轮 `artifacts/tests/` 报告（不公开）。普通主输入框在线/断网、真实权限拒绝与恢复、复制降级、原目标失效已完成手工系统验收。question 框与第 5 项的拓展系统场景仍按边界单独标注，不假设兼容。

公开仓库不附原始运行报告、会话日志和私人数据库。历史验收摘要见 [stage1-acceptance.md](stage1-acceptance.md)；执行套件会在本机重新生成证据。发布与回滚约定见 [development.md](development.md)。

2026-10-30 新版 UI 最终回归：48 Swift + 7 Python + 103 原生检查、19 张有效截图通过；原生红黄绿按钮实际最小化／还原、放大与关闭通过。构建 20261030T152933Z，报告见本地 artifacts/tests/20261030T152927.116265Z/summary.json。本轮未重复真实 Codex 跨应用插入。

2026-10-30 试用反馈修正：完整套件 48 Swift + 7 Python + 107 原生检查、19 张截图通过，构建 20261030T154236Z。新增进入／退出原生全屏通知与样式、regular 身份和实际 Logo 渲染校验；真实绿色按钮也已手动点击验证进入全屏。报告 artifacts/tests/20261030T154230.766752Z/summary.json。

2026-10-31 对齐与透明图标：完整套件 52 Swift + 7 Python + 108 原生检查、19 张有效截图通过，构建 20261030T162750Z。新增可见字形中线、翻转绘制方向、紧凑行模式与图标外围透明回归；原生同时检查源图、运行时应用图标和 ICNS。报告 artifacts/tests/20261030T162746.795484Z/summary.json。已正常重启并打开管理页，实际 Dock 画面因工具目标超时未目测，真实跨应用插入未重测。

2026-10-31 main 合并包：73 Swift + 7 Python + 111 原生检查、19 张截图通过。报告 artifacts/tests/20261031T011328.865456Z/summary.json，独立审查构建 20261031T011333Z，指纹 20baaf6093e9d54128c44a1dfa7e9f3e7c2ce543c1fa3a8185f7c0b9a38941e4。保留两边回归，将旧表单三组测试迁移到当前编辑器，补分类迁移时旧列表刷新／详情跟随；原生经真实管理入口检查独立窗口、必填和正文 Return 编辑不保存。旧阶段的真实短 Prompt 插入记录保留，本次不冒称已复验合并包外部输入框。

## v0.3 新增回归

`GenerationTests`：结构/字段/未知 ID/分类互斥校验，候选明确采用与来源保真，第六分类去重、旧 ID/历史计次/重启，分类与条目事务失败保留草稿。`GenerationFlowTests`：请求前落盘、超时/取消/重试/迟到结果/请求中手改、候选恢复及保存刷新。`DeepSeekClientTests`：URLProtocol 模拟请求/HTTP/超时/截断，原样发送输入与当前分类、无工具、JSON 模式与 high 思考。

原生新增候选审核/来源保真、第六类侧栏/预览/浮窗正文/统计；三张新截图 `management-candidate`、`management-new-category`、`management-sixth-statistics`。HTTP 与候选均模拟，不代表实际供应商或真实系统插入验收。

2026-11-01 v0.3 最终功能回归：完整 `python3 scripts/test-suite.py` 通过 **83 Swift、8 Python、122 原生检查、22 张截图**。独立审查包构建 `20261101T032743Z`，源码指纹 `74453fa9618984d49978d968ea1c5cb1f05c1567d978fd4a3a396fb1a365683c`，本机报告 `artifacts/tests/20261101T032734.760510Z/summary.json`。候选字段直接编辑、重新生成的确认/取消、失败保留手改候选及临时凭证文件拒绝坏输入也在回归内。过程中曾出现异步 UI 断言过早和新分类输入框裁切；保留失败报告，修正后整套重跑通过。

同日真实 DeepSeek 验收：用户提供 key 后，签名审查包通过 `--import-deepseek-key-file` 导入 Keychain、回读确认并清空本机临时文件（不在仓库）。另一进程以 `--verify-generation` 从 Keychain 读 key，实际请求 deepseek-flash/high，完成公开项目经验整理 → 候选内编辑 → 原文/来源保真 → 临时 SQLite 保存 → 重新打开字段一致。构建 `20261101T032653Z`，本机证据 `artifacts/llm-real/20261101-flash1017/report.json`、`generated-entry.json`。该构建与最终 UI 回归包的 DeepSeek 请求、Keychain 与候选采用逻辑相同；之后仅加候选替换确认测试接缝、验收工具空分类保护与错误码。真实 API 只有这 1 条样本，不宣称普遍语义质量；真实 Codex 跨应用与物理断网未在本轮重测，正式资料库未改动。

2026-11-01 后续真实 20 条实验与最终回归：用户提供 Tw93 正文，逐条真实调用并经审核精简后保存正式库，8 → 28 条、5 → 7 类；原始输出与审核稿均留在本机 `artifacts/experiments/tw93-2115366100221501540/`。两库先通过 SQLite backup API 保留一致快照；保存后逐字段比对原文、来源和 ID，正式草稿与历史使用记录未变。正常启动审查包后，真实管理窗口显示 28 条/7 类，并选中第 9 条核对已保存 Prompt。

实验发现“先说明”被模型扩写成等待批准、可选做法变强制、日志内容被虚构等语义偏差；已审核修剪保存稿并收紧系统提示词。第 9 条在隔离库再次真实生成，确认不再添加批准门槛；不据此保证所有生成结果语义正确。新增 PI-018 草稿归属回归：修复前失败，事务中仅清理本次条目草稿后通过。

最终同入口完整通过 **84 Swift、8 Python、122 原生检查、22 张截图**，报告 `artifacts/tests/20261101T034010.793041Z/summary.json`；构建 `20261101T034018Z`，源码指纹 `01fbaf33aad6b164b7ba4f366b3d689c8ebc99219db61607c19f0ec3f433f1a4`。本轮真实 API 共 20 条用户经验及 2 条验收/提示词对照样本；真实 Codex 跨应用与物理断网仍未重测。
