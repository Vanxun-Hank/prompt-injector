# 经验理解与整理 · V5 原型 brief

模式：Operate。本文记录 V5 Figma 的目标流程、可点击状态与历史证据；实现授权、审核状态只在 [prototype.md](prototype.md) 维护。V5 已接入当前 AppKit 开发版，实际 LLM、会话持久化、批量保存与删除边界见 [experience-dialogue.md](experience-dialogue.md)。下述原型的预设回复、点击与保存演示仍只作为原型证据，不改写为真实功能验证。

## 当前双栏方案

用户最新反馈将主内容改回左右各半：左侧聊天，右侧识别出的经验；216 pt 分类侧栏保留。两列独立滚动，聊天输入框固定底部，右列底部固定勾选数量与「整理已勾选」。默认 1440×960 时两列各 568 pt，最小 1100×720 时各 398 pt。V4 的居中会话与按需抽屉布局已被本次反馈替代，V3／V4 设计保留为历史。

- 点经验文字自动发起该条讨论：原型聊天区显示「一起讨论第 N 条」消息及对应的预设回复，并高亮当前经验。20 条文字均有变量交互；文字点击不改变勾选。
- 复选框有独立的 44 pt 点击区域，只负责勾选／取消和数量变化。讨论高亮与复选框分别表达「正在讨论」和「确认整理」，不互相代替。
- 每轮用户消息与模型回复结束后有细分隔线；第 8／9 条提供下一轮预设追问，呈现多轮讨论。
- 来源与原文合并为「X · HiTw93 · 作者原文」入口。打开后只显示当前经验编号与作者原句，内部另有「在 X 查看完整帖子」链接，不将整篇 20 条正文放进当前经验的原文面板。
- 后续候选仍分开呈现 Prompt、作者原文和整理说明。讨论补充单独标识，不冒充作者原话；保存与删除均为演示状态。

## 分类色与原生边界

保留原五色及顺序，新增十色形成十五色循环，第 16 类回到第 1 色。当前 App 按数据库返回的完整分类顺序映射，不按当前筛选重新编号；分类名称始终保留，不靠颜色作为唯一标识，不因色板增加分类或设置项。

Figma 十五色依次为 `#F5D975`、`#99A8FF`、`#FFAA85`、`#C5A0FF`、`#F699C8`、`#74D5A8`、`#71CDD9`、`#BEDA7B`、`#D8B279`、`#79B7EE`、`#D999AF`、`#9EBBA6`、`#B9A58F`、`#CED1A3`、`#AAAFCB`。六个沿用的浏览预览也将第 7 分类统一为与侧栏相同的青色；此补齐未改主会话、最小窗口或色板。Figma 使用既有 Noto Sans SC／Inter；App 继续使用系统字体。

[DESIGN.md](../DESIGN.md) 与 `.impeccable/design.json` 已依据当前 AppKit 同步十五色、会话与审核组件；前五色保持原值，系统字体、原生窗口、焦点和键盘规则继续保留。

## 原型演示边界

本节是 V5 Figma 阶段的历史边界；真实客户端的实现与验证另见 [experience-dialogue.md](experience-dialogue.md) 和 [testing.md](testing.md)。

- 单条与 20 条经验来自用户提供的 Tw93 公开正文。20 条均可点击文字讨论、独立勾选并计数；回复为预设内容，未调用真实 LLM，也未抓取任意链接或处理任意输入。
- 追问只演示第 8「用脚本验证规则」与第 9「动手前说明改动」。审核／保存演示继续使用第 8／9 条候选，不代表任意勾选组合能真实生成或批量保存。
- 原型切换经验会重置预设追问。当时要求正式实现按经验稳定 ID 保留各条讨论与输入，切换不得丢失用户内容；失败、取消、重试和新结果不得静默覆盖已编辑内容。当前实现已接入这些保护，具体测试仍独立记录。
- 候选、保存提示和删除后的页面都是原型状态，未保存或删除任何本地内容。当时尚未实现链接读取、生成及保存／删除策略；当前实现的数据行为以实现文档和测试报告为准。
- 本轮未测试客户端或真实 API，未运行 `python3 scripts/test-suite.py`；仅核对 Figma 设计、点击证据和文档。

## V5 设计与点击证据

Figma 文件 `2HmvWbRy3wnjiMOwrbh6A6`，V5 页面 `323:9335`；多条主画面 `323:9411`，单条 `323:9893`，最小窗口 `323:9652`，作者原文 `323:10001`，十五色板 `323:12388`。结构校验记录默认两列 568／568 pt、最小两列 398／398 pt，41 组文字与复选框独立点击区（默认 20、最小 20、单条 1）、15 个唯一色以及第 16 色点引用第 1 色。节点记录见 [.impeccable/conversation-v5/nodes.json](../.impeccable/conversation-v5/nodes.json)：872 个文本节点、485 个组件实例，无整屏 UI 位图；变量分别承载当前经验、原文、讨论消息、追问、勾选与高亮。范围见 [scope.md](../artifacts/conversation-v5/scope.md)。

网页原型已实际点通：讨论第 9 条时勾选第 8 条，计数为 1；再勾选第 9 条、取消第 8 条，计数仍为 1，且讨论不变。统一原文入口显示第 9 条原句，关闭后回到讨论；点击发送显示第 9 条预设追问与两条分隔线。再次勾选第 8 条并点击「整理已勾选」，进入第 8／9 条预设候选的 1／2 审核。此路径不验证任意勾选组合的审核或保存。

| 范围 | 证据 |
| --- | --- |
| 1440×960 左聊天／右经验 | [multi.png](../artifacts/conversation-v5/multi.png) |
| 1100×720 最小窗口 | [minimum.png](../artifacts/conversation-v5/minimum.png) |
| 保留前五色，十五色循环，16→1 | [palette.png](../artifacts/conversation-v5/palette.png) |
| 讨论第 9 条时，第 8 条保持独立勾选 | [checkbox-proof.png](../artifacts/conversation-v5/checkbox-proof.png) |
| 合并来源入口，只显示当前第 9 条原话 | [original-proof.png](../artifacts/conversation-v5/original-proof.png) |
| 第 9 条预设追问与每轮分隔线 | [dividers-proof.png](../artifacts/conversation-v5/dividers-proof.png) |

## 当前原生画面对照

当前 App 使用系统字体；下列截图为两条经验的原生 fixture，Figma 上述二十条列表、预设回复和勾选数量不代表截图的数据量。它们用于对照默认／最小等宽双栏、分隔线、独立讨论／勾选和候选审核；真实网络与数据库流程见独立报告。

| 原生状态 | 证据 |
| --- | --- |
| 双栏讨论与独立勾选 | [experience-chat.png](../artifacts/tests/20261102T161703.310103Z/ui/experience-chat.png) |
| 1100×720、各列独立滚动 | [experience-minimum.png](../artifacts/tests/20261102T161703.310103Z/ui/experience-minimum.png) |
| 两条候选逐条审核与明确保存数量 | [experience-review.png](../artifacts/tests/20261102T161703.310103Z/ui/experience-review.png) |
| 审核页当前经验作者原文 | [experience-original.png](../artifacts/tests/20261102T161703.310103Z/ui/experience-original.png) |

## V4 历史 brief

以下保留 V4 的流程和证据记录。其居中会话／抽屉布局不再作为当前设计依据；本节中的「本轮」均指 V4 当时的工作。

模式：Operate。基于当前 App／阅读 V2，在原 Figma 文件制作可编辑、可点击的设计稿；不修改客户端或正式资料库。实现授权、审核状态只在 prototype.md 维护。

### 流程约定

- 加号进入对话入口，直接接收原文或链接；不先要求填写所有字段。链接可读取时保留来源与整篇原文，再识别一条或多条经验；失败可粘贴正文继续，不让模型编造网页内容。
- 单条直接讨论；多条以按需展开的经验列表供选择。点击某条切换讨论上下文，选择哪些要整理；每条有独立的标题、简述、分类、解释与 Prompt，对应原句和共同来源。对拆分有异议可在对话中说明，不把整篇多条内容硬塞成一个 Prompt。
- 用户多轮厘清概念后点击「整理并填入」。模型根据原文与明确的讨论补充填入候选，用户审核修改后保存。讨论补充按含义进入解释或 Prompt，解释中标明「讨论补充」，不伪装成作者原话；原文、链接和作者来源不自动改写。
- 多条分别审核，可在待保存条目之间切换，明确显示本次保存数量。保存前均为草稿，失败、取消与重试保留输入；新结果不能静默覆盖用户后续编辑。
- 来源显示平台 Logo、名称与可读链接；本轮覆盖 X、GitHub、Reddit，未知平台用通用链接标识。删除放在条目操作区，先确认具体条目，再演示移除；不增加回收站入口、账号、模型选择、抓取配置或其他开关。

### 会话层级与视觉

用户否决 V3 的聊天布局，要求参考 Claude Code／Codex。V4 以连续会话作为主区域，居中限宽的消息流承载多轮理解，底部固定多行输入框。顶部保留当前经验、来源、作者原文入口，以及「20 条 · 已选 2 条」这类数量入口；来源和多经验选择按需从右侧展开，不常驻挤占会话。会话与侧栏列表分别滚动，整理动作固定在顶部；完整字段集中到后续审核页。

延续 216 pt 深色侧栏、系统窗口按钮、现有 Logo／图标、五色分类循环、短标题和分层阅读。默认 1440×960，最小 1100×720。审核页保留「Prompt／作者原文／整理说明」分段、逐条切换与明确的保存数量；删除确认点名待删条目并提供取消。

本轮是既有深色原生视觉内的新流程设计。Figma 使用 Noto Sans SC／Inter，App 继续使用系统字体；现行 DESIGN.md 与 `.impeccable/design.json` 保持原样，不把本轮待审会话布局写成全局规范。不复制模型选择、权限模式、附件或终端等无关控件。参考用户提供的 Codex 界面截图与 Claude Code 官方 Desktop 文档；工具禁止读取 Codex 自身窗口，不绕过限制。

### 原型演示边界

- 使用用户提供的 Tw93 公开正文，包含单条与 20 条经验的预设路径；多条演示勾选第 8「用脚本验证规则」和第 9「动手前说明改动」，再分别审核两条候选。20 条是示例列表，不代表原型能对任意链接抓取、拆分或处理任意输入。
- 连续对话、候选字段、草稿／保存提示和移除后的页面均为原型状态；原型未执行链接抓取或 LLM 请求，未保存候选或删除本地内容。作者原文保真，讨论补充单独标识，不冒充作者意见。
- 链接读取失败、生成失败／取消／重试、用户已修改候选以及本地保存／删除的数据行为，须在正式实现时补齐策略和相关测试。本轮未决定删除的数据策略，不增加回收站或配置项。

### 设计证据入口

Figma 文件 `2HmvWbRy3wnjiMOwrbh6A6`，V4 页面 `272:4664`，主会话 `272:4899`。六份最终证据均为 Figma 网页版原生 1× 导出；可编辑结构检查记录 1,258 个文本节点与 811 个组件实例，无整屏 UI 位图。审核结论及实现授权只见 [prototype.md](prototype.md)。

| 状态 | 最终导出 |
| --- | --- |
| 连续会话／经验列表收起 | [multiChat.png](../artifacts/conversation-v4/native-final/multiChat.png) |
| 来源与多经验列表展开 | [multiChatOpen.png](../artifacts/conversation-v4/native-final/multiChatOpen.png) |
| 1100×720 最小窗口 | [minimum.png](../artifacts/conversation-v4/native-final/minimum.png) |
| 两条候选逐条审核 | [reviewBatch.png](../artifacts/conversation-v4/native-final/reviewBatch.png) |
| 删除确认 | [deleteConfirm.png](../artifacts/conversation-v4/native-final/deleteConfirm.png) |
| X／GitHub／Reddit 来源 Logo | [source-logos.png](../artifacts/conversation-v4/native-final/source-logos.png) |


### 网页原型实际点击补证

已在网页版实际点通：单条经验进入审核／保存演示，经验列表展开／切换第9条／收起、该条作者原文、整理两条候选、切到2/2及其原文／整理说明、保存两条的演示结果；独立删除场景的确认、取消和移除演示。1100×720 会话区实际滚动后可读到最后一句，底部输入框保持固定。证据为 artifacts/conversation-v4/report.json、explanation-proof.png、minimum-scroll-proof.png。以上均为预设原型状态切换，不操作 SQLite 或真实 LLM。

交互参考：[Claude Code Desktop](https://code.claude.com/docs/en/desktop)、[Codex App 官方介绍](https://openai.com/index/introducing-the-codex-app/) 与用户提供的 Codex 截图；这些用于会话组织的参考，不声明逐像素复制。
