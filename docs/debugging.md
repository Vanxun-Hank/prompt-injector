# 日志与 bug 排查

## 先确认版本，再复现

1. 记录预期、实际结果、最短操作步骤及发生时间；插入问题先确认原输入框是否已有内容，避免重复粘贴。
2. 查看应用日志的 `build.buildID`、`sourceFingerprint`、`revision`，与 `build/build-info.json` 对照，先排除运行旧包。当前目录尚无 Git 提交时，`revision` 为 `unversioned`，以代码指纹和 [CHANGELOG](../CHANGELOG.md) 定位改动；不要猜提交号。
3. 用失败事件的 `operationID` 查完整链路，包括它关联的 `captureID`。不要把上一轮的成功、设置里的开关或模拟结果当作本轮成功。
4. 根据停留阶段复现、定位根因。先添加能暴露问题的最小测试，再修复；如只能在真实系统复现，记录手动步骤和证据，明确自动测试的边界。
5. 检查同类路径：所有早退/异常分支、相同能力判断、邻近的输入/选区/配置边界。只修有证据的同类问题，不顺手扩大到无关重构。
6. 修复后运行关联测试与必要的集成检查；在 [bugs.md](bugs.md) 记录根因、修复和测试，在 CHANGELOG 记录变化。不要把“有测试”写成所有系统场景已经验收。

## 日志位置与读取

仅本地写入 `~/Library/Logs/Prompt Injector/`，不上传。当前文件 `events.jsonl`；最多保留 `events.1.jsonl` 到 `events.3.jsonl`。每个最多 1 MiB，总上限约 4 MiB（另有一个空锁文件）。历史会滚动覆盖，需要长期保留时复制相关文件。

在项目根目录运行（Python 3 标准库，无额外依赖）：

```sh
python3 scripts/read-logs.py --last 80
python3 scripts/read-logs.py --level error --last 20
python3 scripts/read-logs.py --operation 实际的operationID --json
python3 scripts/read-logs.py --build 实际的buildID
```

查看工具包含归档，会在文件轮转时容忍文件消失，对不完整行明确报告跳过。日志若因磁盘/权限等失败，应用继续工作，标准错误流仅提示日志不可用，不回显可能带私人路径的错误内容。

每条记录含 UTC 时间、会话 ID、序号、进程 ID、版本、构建 ID、源码指纹、系统版本、运行模式、级别与事件。UI 自动验证用 `mode=ui-verification` 标记，不能与真实用户操作混同。后台串行写盘，跨进程用锁保护追加与轮转；没有空闲轮询。

## 主要事件

| 事件 | 含义 |
| --- | --- |
| `storage.opened/migrating/query/failed` | 数据库打开、首次迁移、按层查询与失败；仅含层级、行数、耗时、错误代码 |
| `app.started` / `app.stopped` | 构建与进程会话边界；异常退出可能没有 stopped |
| `permission.changed` / `permission.requested` | 实际进程授权变化、用户请求系统授权 |
| `shortcut.*` / `preference.invalid` | 快捷键注册结果、配置回退 |
| `launcher.*` / `page.changed` / `copy.*` | 显示隐藏、层级切换、完整 Prompt 复制结果 |
| `management.opened/save` / `storage.save_started/saved/failed` | 新增入口、必填早退、重复点击忽略、后台事务提交或失败；同次保存以 operationID 关联，不记录字段值 |
| `library.refreshed/load_discarded` | 保存后的受影响页重载、按查询代次丢弃迟到结果 |
| `capture.started/ready/failed` | 新目标捕获与文本/选区/编辑能力判断 |
| `insertion.started/stage/write_requested` | 权限、目标、松开快捷键、恢复焦点、写入与验证阶段 |
| `insertion.verified/failed/unconfirmed` | 回读匹配、明确失败、写入后无法确认 |
| `clipboard.restored/kept` | 恢复原剪贴板，或因所有权变化保留用户新内容 |

诊断字段为固定类型：阶段、错误代码、能力布尔值、目标 bundle ID、角色、长度、耗时等。禁止记录 Prompt、经验原文、输入框正文、剪贴板数据、来源 URL、凭证或逐键输入；不接受任意文本 payload。

调查版日志曾附加 `axCharacterCount`、`placeholderUTF16Count`、`valueMatchesPlaceholder`、`rangeTextUTF16Count`、`valueMatchesRangeText`、`rangeReadCode`。它们是当时的计数、API 结果和相等关系；字段缺失不当作零。修复版已移除这些探索性读取，历史原始 JSONL 仍可由查看工具读取，没有占位文本或输入正文。

对 Codex 的非空 AXTextArea 读取值、零长度起始选区，另在捕获目标内部最多检查 32 个节点的 `AXDOMClassList`。仅记录 `domClassMetadataAvailable`、`proseMirrorRootSeen`、`emptyComposerMarkerSeen`、`inspectedNodeCount`；不记录类名数组或子节点文本，也不查询其他窗口。标记“未见”不等于空框。真实采集确认可靠标记后，PI-016 仅用根/空段落标记同时存在的结构证据解析空文档；没有标记时保留原值与严格匹配。

`axValueUTF16Count` 为捕获时原始 AXValue 的长度；`beforeUTF16Count` 为插入计划使用的实际正文长度。修复后的已识别空框应见原始值非零、正文为 0、`emptyComposerNormalized=true`。这仍不是插入成功，必须再看同 operationID 的 `insertion.verified` 与用户未发送确认。结构/原值/选区读取变化时不会完成归一化。

`insertion.lastResult` 和 `accessibility.permissionSnapshot` 保留为快速状态快照；完整历史以 JSONL 为准。新的捕获/插入与所有提前失败均更新结果，避免旧成功状态残留。

## 验证命令

```sh
python3 scripts/test-suite.py
```

完整套件与分组案例见 [testing.md](testing.md)。

真正的辅助功能、跨应用焦点和实际粘贴仍需系统验收。工具若禁止操作目标应用，由用户亲手操作，再结合程序日志与用户观察确认；不能绕过工具限制，也不能用单元测试冒充实测。

原生截图和窗口动画验收需要已解锁的桌面。锁屏时捕获失败或动画完成时机异常，不可据此宣称正常桌面行为通过；保留本次失败报告、注明环境，并在解锁后复验。旧截图也不能标成当前构建的新截图。
