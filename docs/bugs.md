# Bug 与回归记录

这些记录为后续开发保留根因和测试入口。系统实测与自动化测试分别列出；不把参数化测试或模拟目标当作真实跨应用验收。原始会话日志仅保存在开发机器的 `artifacts/`，不公开。

| 编号 | 现象 / 根因 | 修复与边界 | 回归入口 |
| --- | --- | --- | --- |
| PI-001 | Codex AXSelectedText 返回成功，但输入框仍空白 | Codex 使用一次标准粘贴，全文回读一致才确认；不自动重试、不发送 | `BugRegressionTests.testCodexUsesPasteAndUnchangedTextCannotPassVerification`；真实主框已验证 |
| PI-002 | 自定义编辑器的 AXGroup 被只看角色的规则拒绝 | 检查文本、选区与编辑能力，安全输入拒绝 | `testCustomEditableGroupIsAcceptedButReadOnlyOrSecureGroupIsNot` |
| PI-003 | 提前失败未更新最后结果，可能残留上次成功 | 捕获/插入早退都有独立操作 ID 与事件，保留完整历史 | `testServiceClearsOldSuccessAndLogsFreshPermissionFailureThenRecapture`、`DiagnosticLogTests` |
| PI-004 | 开启权限后仍沿用未授权时的捕获失败 | 使用当前权限，要求重新唤起捕获目标，不继续报“未授权” | `testNewPermissionRequiresRecaptureInsteadOfReportingPermissionDeniedAgain`、真实服务早退测试 |
| PI-005 | 负数快捷键索引可能越界；窗口配置缺少有限值检查 | 无效索引回退默认，损坏窗口框回退初始位置；允许外接显示器负坐标 | `testInvalidShortcutPreferencesFallBackToFirstOption`、`testRelatedMalformedWindowPreferencesAreRejected` |
| PI-006 | 系统开关已开，但重建后的临时签名程序仍无权限 | 使用有效开发证书保持身份；用户重新添加当前 `.app` 授权 | 实际进程 trusted 与签名检查；TCC 行为不能纯单测证明 |
| PI-007 | Codex 标准粘贴路径仍要求 AX setter 可写 | 按实际插入方法判断，Codex 的聚焦 AXGroup 可作为候选；明确只读/禁用/安全/不可读仍拒绝 | `PasteCapabilityTests.testObservedCodexGroupCanPasteWithoutAXSetters` 修复前失败、修复后通过；另测其他应用不扩大兼容 |
| PI-008 | 非文本控件可能因 value 可写被当作输入框；错误提示也不够明确 | 按钮、勾选框、单选框、滑块、弹出按钮和菜单项明确拒绝，提示重新从文字输入框唤起 | `testNonTextControlsRemainRejectedEvenWithWritableValue` 覆盖两种写入方式，修复前 12 个断言失败、修复后通过 |
| PI-009 | 新增异步退出排空后，MainActor Task 调用 terminate 进入 terminateLater 嵌套事件循环，主队列完成回调无法执行，进程卡住 | 先返回 terminateCancel，异步完成草稿与队列排空后再次退出；失败保留应用与表单 | `ManagementTests.testMainActorTerminationExitsAfterPendingUsageIsCommitted`：旧实现实测 3 秒超时失败，修复后进程正常退出且使用记录落盘；不依赖桌面截图 |
| PI-010 | 小窗超长标题只缩小 NSTextView 的 frame，文字布局仍有 234 pt 高，会绘制到下方页签 | 标题布局限为两行并截尾，保留完整 tooltip／原始字段；正文仍独立滚动 | `NavigationTests.testLongTitleDoesNotPaintBehindDetailControls` 修复前 234 > 52 失败，修复后通过；原生长内容截图复核 |
| PI-011 | 插入失败后 defer 无条件重新启用按钮，错误态仍能通过按钮／⌘Return 发起操作 | 已确认权限／目标／未确认写入失败保持禁用，复制不受影响；新目标捕获成功才恢复，剪贴板与快捷键暂态错误仍可重试 | `NavigationTests.testPermissionFailureDisablesInsertionAndPreservesCopy` 修复前失败；原生 `keyboard/blocked-command-return-no-route` 与恢复检查 |
| PI-012 | 管理窗口只具备普通缩放行为，应用仍为 accessory 辅助程序，缺少主全屏窗口配置 | 管理窗口增加 fullScreenPrimary，打开后切换 regular 并显式应用品牌图标；Dock 重开管理窗口，提供 ⌃⌘F | 原生 management/native-fullscreen-space 与 native-fullscreen-exit；真实绿色按钮 AX 从 zoom 变为 full screen，点击后记录 fullscreen-entered；application/branded-icon 对实际渲染像素校验 |

## 系统排查中应保留的判断

- 多次按插入不等于多次捕获。更换目标需先收起浮窗，在新输入框确认光标，再重新唤起；仅切换 Prompt 不改变目标。
- 用户曾报告“两个框都失败”，但日志显示多次复用同一个 AXButton 目标；重新在普通框键入测试文字并完整唤起后，真实插入通过。不要根据口述次数猜目标数量，也不要为绕过错误把按钮放行。
- 锁屏导致过截图和窗口动画时序检查失败；同构建解锁后通过。保留环境与失败报告，不删断言、不拿旧截图冒充新运行结果。
- UI QA 的所有唤起路径都必须捕获 nil，不能测试时读取外部输入框。验证进程不注册全局快捷键，使用临时 SQLite。

## SQLite 与异步界面防护

`SQLiteRepositoryTests` 覆盖首次事务导入、重启不重复、不覆盖编辑/复活删除、损坏与高版本库保留、并发初始化、Unicode/NUL 保真、参数绑定。通过 SQLite authorizer 禁止正文列读取，证明分类/列表不提前加载正文。

`LibraryLoadingTests` 覆盖迟到详情不能覆盖新页面、读取失败不能插入旧 Prompt、重新读取恢复、选择记忆及完整 Prompt 原样传递。这些是预防性回归，不冒称均曾在用户环境发生。

`InsertionTests` 继续覆盖 UTF-16/emoji 选区、未写入与重复内容不能通过确认、多个剪贴板条目/类型恢复，以及后来用户复制内容不被覆盖。套件查看工具防止缺失截图或单项失败被顶层 passed 掩盖。

## 后续兼容性：question 自由回答框

该框曾显示文字已插入、未提交，但 AX 回读少两个连续空行，其他字符一致。没有足够证据区分编辑器实际合并空行与 AX 回读省略；因此保留 unconfirmed，不宣称完整格式兼容。

用户明确普通主输入框才是 Stage 1 目标，这个问题延期，不继续阻挡阶段交付。`InsertionObservationTests` 确保差异诊断不能绕过严格全文校验：忽略空行后相等并不算成功，前缀缺失或空白被裁剪同样不通过。

后续修复在这里记录最短复现、根因、修复边界、测试函数及未覆盖范围；实际源码历史以 Git commit 为准。
