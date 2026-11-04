# 管理 UI 修复 · v0.5.1

2026-11-04。本轮保留现有原生布局，先修 Figma V7，再修对应的 AppKit 交互；未整体迁移 V7 卡片网格、原位编辑或连续单页工作台。不新增聊天、开关、依赖或模型资源。

## 设计稿与原生实现

[V7 画布](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=386-1662) · [交互原型](https://www.figma.com/proto/2HmvWbRy3wnjiMOwrbh6A6?node-id=386-1662&starting-point-node-id=386%3A1662&scaling=scale-down&content-scaling=fixed)

| 项目 | Figma 修复 | AppKit 实现 |
| --- | --- | --- |
| 分类筛选 | category `386:2015` 仅含编码3条；`415:1962` 为编码 AND 测试1条 | SQL 原本正确，未改查询；发新查询清空旧 rows／详情／计数，代次和页面拦截迟到结果 |
| 分类选择 | `388:630` 280×346，手动锚点相对字段；彩点、当前勾选、键盘及外部关闭 | 新 CategoryPopover 复用 NSPopover transient、NSTableView 与既有颜色资源 |
| 新建分类 | 同一 Popover 切换表单；`388:723` 为画布参考；空名／重名／失败参考为 `415:1926`、`415:1938`、`415:1950` | 空名就地反馈、焦点留输入框；规范化重名选已有ID；新名称暂存草稿，保存条目时同事务去重创建，失败保留输入且不遗留孤立分类 |
| 删除 | `388:800` 420×204；点名条目、取消描边、删除中性填充；取消返回原阅读分页 | 详情 More 内删除；紧凑原生 NSAlert，取消为 Return 默认和初始焦点，无红色按钮 |
| 比较 | `388:547` 780×464，两栏保留上下文与新增段落 | PromptComparisonView 720×300，当前／新建议均只读，可滚动并高亮改变范围；明确保留／采用 |
| 字段验证 | 标题 `415:1786`，Prompt `388:945`，错误靠近字段 | 标题、分类、Prompt 就地验证并聚焦；候选必填也就地提示，普通错误不弹 Modal |
| 保存状态 | 剩19 `388:2514`、剩4 `415:1034`、剩0 `415:1289`；不复用原20条分母 | 只保存人工确认项；剩余分母、当前ID、草稿由同一 remaining 状态生成；审核空 Prompt 项保留，按稳定ID导航 |
| 详情操作 | 阅读页统一右下复制、编辑、更多 | 复用 ActionButton；复制主操作、编辑次级、删除移入 NSMenu |

分类列表来自 SQLite。Popover 的「创建并使用」先选择待建名称，正式保存才写数据库，沿用本项目既有事务边界。重名既在菜单规范化匹配，也在写事务内去重；重复点击不会创建重复分类。

## 选择、生成与确认

单击列表只切换查看。复选框只决定 generateSelected 的批量范围，未选中也可查看／审核已有 Prompt。识别单条和多条都先等待明确生成；手贴 Prompt 不调用模型。

候选存在后可审核，确认按钮独立。修改标题、分类、简述、解释或 Prompt 都会恢复待确认。仅 confirmed 项可以写入正式库；未保存项及原文／来源留在伴随库草稿。旧草稿没有 confirmed 时视为待确认，原有勾选不会自动成为批准。

重新生成已有 Prompt 时，结果保存到 suggestion；保留当前版本不改候选，采用新版本才替换并恢复待确认。后续手改会清除旧 suggestion，采用动作再次校验对应快照。切到另一条不取消原条生成；取消、失败和迟到响应仍受 operationID／候选快照保护。

审核列表保留暂时为空的 Prompt，避免删空后旧行索引对应新集合。字段验证拦截空值确认，用户可以切到另一条再回来补充。

## 既有系统对照

独立 documenter 对照 PRODUCT.md、DESIGN.md、`.impeccable/design.json`、源码及默认／最小窗口截图：延续深色中性面、细灰边、白色操作和十五色分类点；复用 SurfaceView、ActionButton、EditorText、DesignAssets、NSPopover 与 NSAlert，未新增 token、字体、图片或依赖。既有字体体系与 Scoped Glow 边界保持。sidecar 仍有 V5 聊天叙述的预存漂移，仅报告，未借本轮修复重写设计系统。

## 实际验证

完整运行：

```sh
PROMPT_INJECTOR_APP_OUTPUT="$PWD/build/Management-Fixes-Review/Prompt Injector.app" python3 scripts/test-suite.py
```

最终报告 `artifacts/tests/20261104T032656.681208Z/summary.json`：119 Swift、9 Python、165 原生检查、36图全部通过；版本0.5.1，build `20261104T032707Z`，source `3bd744da77a239d24cd1f86bc183cfef29a40180ebaf6ef9f6607960456bf546`。

新增回归入口：ManagementFilteringTests、ManagementInteractionTests、ManagementTests 的分类ID＋AND案例、ExperienceTests 的1／5／20条生成及部分保存。分类旧行问题修复前已复现失败，而 SQL 交集测试原先通过。审核清空 Prompt 再切条的独立用例修复前5断言失败，修复后通过。测试均采用临时库、控制服务／模拟 HTTP；既有真实数据不作为夹具。

原生截图检查1440×960和1100×720，包含分类表单、字段验证、删除／比较 sheet、确认按钮、审核与来源可见性。首次单独捕获 sheet 得到黑图，未作为最终证据；最终从父窗口捕获关联窗口。结果见 `artifacts/ui/`，套件还校验实际 sheet 可见及安全默认按钮。

Figma 通过网页实际操作：编码3条及编码 AND 测试1条；分类上下键／Enter、Escape、点外部关闭；同一 Popover 内新建、创建后选择；More→居中删除→取消回原详情。`artifacts/management-v7-fixes/` 保留修改前结构、修改脚本、修改后截图及网页证据。Figma 的 API、字段输入、保存和失败是预设样例，不是实际数据库或网络调用。

Figma 首次复核两项表单按钮修复后均 resolved／ship；原生首次复核发现空 Prompt 审核索引问题，修复后仅该项复核为 resolved。不把针对修复项的 verdict 当作全系统审查通过。

本轮未请求真实 DeepSeek，未复验物理断网、真实 Codex 跨应用填写、VoiceOver、系统 Reduce Motion 或最低macOS。插入核心源码未修改，原有路由／复制／历史统计回归保留，但不以模拟结果代替真实系统验收。

## 安装与数据

同一签名审查包原样更新到 `~/Library/Application Support/Prompt Injector/Build/Prompt Injector.app`。安装前无 App 实例运行，先保存旧包及成对 SQLite 备份；包逐文件摘要与签名通过，两库用户表摘要安装前后不变。旧数据实际为0条内容、7分类、5使用记录、1份经验草稿，不回填早期已删除的内容。新版已实际打开，已有3条经验草稿可恢复；没有请求生成或保存正式条目。

运行PID50476／build20261104T032707Z已核对。恢复草稿后payload的JSON键顺序变化，解码内容、revision和全部条目字段一致，规范化两库摘要相同，不声称字节不变。安装记录 `artifacts/installation/v051/report.json`，运行截图 `installed-app.png`。两库与旧包备份：

`~/Library/Application Support/Prompt Injector/Backups/before-v051-20261104T033121Z/`

## 回滚和恢复

- Figma：修复前整页备份 `408:1124`，名称「内容管理 · v7 修复前备份 2026-11-04」。切回备份审阅或在原文件内恢复对应画面；不要删除现有原稿模拟回滚。
- 代码／App：退出所有实例，再用上述备份内旧 App 替换常用路径，或在干净分支撤销本轮修复提交并重建。代码回滚不恢复已保存、修改或删除的条目。旧0.5.0仍使用勾选保存语义，回退后须重新检查批量选择；旧版不展示新建议／确认状态。
- 数据：本轮未改 schema，也未对正式内容执行写入。只有需要恢复内容时，先退出并另备份当前状态，再成对恢复同一时点 library.sqlite3 与 library-activity.sqlite3。不要单独删除伴随库，或把较早备份覆盖后来有效编辑。Keychain未改，不随数据库恢复。

