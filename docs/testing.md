# Stage 1 回归测试套件

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
