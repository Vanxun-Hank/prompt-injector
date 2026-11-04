# 内容管理 V7 · Ponytail 工作台

2026-11-04。模式 Operate / Read。本文记录初版可编辑 Figma 网页画布与可点击原型；后续十项修复及对应 AppKit 实现见 [管理 UI 修复](management-ui-fixes.md)，最新授权及审核状态统一见 [prototype.md](prototype.md)。参照用户钉选的 Ponytail dashboard 黑色底板、柔光分类点与细边框，结合 Square 的紧凑文字卡片、Linear 的连续工作台机制：内容库发现，工作台生产与审核，浮窗快速使用。

## 设计约定

全部内容默认紧凑卡片网格；点击卡片进入保留搜索和分类上下文的列表／详情。已有条目原位编辑，保存保持选中。新增使用统一单／多条工作台，左列表、右完整编辑区，原文／来源独立保留、可折叠原文、Prompt 占主区域。生成与条目绑定，切换不应取消正在处理的另一条；错误／进度／确认标在对应条目。只有已确认条目入库，其余留草稿。这些是下一版的行为约定，本轮通过预设状态表达，尚非客户端实现。

使用统计保留入口，本轮不重做统计和快捷浮窗；不增加聊天、收藏、标签、回收站、账号或模型设置。

## 已确认的产品决策

1. 识别后先勾选，再明确点击生成所选。
2. 已确认后再修改标题／分类／Prompt，恢复待确认。
3. 重新生成后新旧并排比较，用户点采用新版本才替换。

用户已在本轮结构化回复中逐项确认，后续不重复询问。

## Direction contract

THESIS：一处连续完成整理，用条目状态交接生成与审核；内容库用于快速扫描。
OWN-WORLD：采用用户钉选的 Ponytail 黑色底板、细边框与十五色圆点；沿用品牌 Logo 和来源图标，不给文字卡增加大封面。
STORY：浏览短标题／一句简述；打开阅读或原位编辑；收集后始终在同一工作区逐条处理。
FIRST VIEWPORT：216px 分类侧栏，主区域顶部标题／搜索／新增；内容网格三列。工作台左侧约300px 条目列表，右侧元信息、原文和大 Prompt 编辑器。
FORM：用户指定 Square 紧凑卡片＋Linear 双栏机制＋Ponytail 视觉，不另开风格赛选；seed: none (user-pinned reference)。
FINISH：unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance。此处 [DESIGN.md](../DESIGN.md) 作为既有生产系统对照，原型采用状态在 prototype.md 单独维护。

## 既有设计系统对照

本轮是既有深色视觉体系的管理流程延伸。保留十五色及其循环顺序、渐变 Logo、来源图标、白色通用操作与中性输入框，柔光集中于既有品牌和分类标记。新卡片网格、原位编辑及连续工作台仅作为 V7 表达，不将其回写成已上线的全局规则。

Figma 继续使用可编辑文字、组件与向量，中文／英文沿用既有 Figma 字体表达；原生系统字体、焦点与键盘行为不因本原型改变。未新增生成图片或外部位图素材；截图是设计证据，既有 Logo／来源资产的出处不变。[DESIGN.md](../DESIGN.md)、`.impeccable/design.json` 与 PRODUCT.md 保留已实现版本的事实。

## 网页画布与入口

沿用文件 `2HmvWbRy3wnjiMOwrbh6A6`，新增 [V7 页面](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=386-1661)，页面 ID 为 `386:1661`；原 V6 保留。50 个根画面组织为五个 section；默认画面 1440 × 960，最小画面 1100 × 720。

| Section | ID | 画面数 |
| --- | --- | --- |
| 内容库 · 浏览分类搜索 | `399:1105` | 6 |
| 阅读与原位编辑 | `399:1106` | 11 |
| 收集经验 · 原文链接手动 | `399:1107` | 5 |
| 经验工作台 · 生成确认恢复 | `399:1108` | 21 |
| 比较分类删除边界状态 | `399:1109` | 7 |

| 入口 | Figma 节点 |
| --- | --- |
| 卡片内容库 | [386:1662](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=386-1662) |
| 识别后工作台 | [387:594](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=387-594) |
| 已生成候选 | [387:1040](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=387-1040) |
| 新旧并排比较 | [388:547](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=388-547) |
| 最小内容库／工作台 | [388:1087](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=388-1087) ／ [388:1582](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=388-1582) |
| 单条／五条示例 | [388:1806](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=388-1806) ／ [388:1916](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=388-1916) |

已另开 Figma Design 网页画布供检查，并保留交互原型页。画布是可编辑图层，不是将截图铺成界面；“可编辑”指 Figma 设计对象，不代表原型表单支持任意键盘输入。

## 本轮验证与证据

最终结构回读记录在 `artifacts/management-v7/structure.json`：50 个根画面、2,766 个文本节点、1,019 个组件实例、零图片填充；748 个导航动作均指向有效节点。主工作台二十个复选框分别绑定二十个不同布尔变量，选择数量使用变量计算；`actions.json` 保留复选框动作与两处 `count > 0` 生成门槛条件。结构存在不代替实际点击验收。

首次 finish review 要求修正四项：比较弹层的工作台上下文、失败后保留现有输入、单条确认按钮文案、复选框真实事件。四项均已调整并重新导出；比较背景可见工作台，失败画面仍展示现有 Prompt，单条按钮为“确认此条”，复选框改为独立变量事件。最终复核裁决为 `resolved / ship`，范围仅限这四项修正，不是全原型或客户端验收。后续还修正五条示例末条仍显示“下一条”的边界，新增末条确认后画面 `401:1105`；采用后的 Prompt 与比较中显示的新建议保持一致。

真实 Figma 网页已点击验证：零勾选触发生成门槛；勾选第一条后计数为 1，再勾第五条并取消第一条后仍为 1，仅第五条保持勾选；复选框操作不切换当前阅读条目。随后点击生成，经过生成中进入预设已生成画面，勾选仍保留；重新生成打开新旧比较，背景保持工作台；点击“采用新版本”进入待确认画面 `387:2610`。此路径的文本与状态仍为预设结果。

| 证据 | 文件（均位于 `artifacts/management-v7/`） |
| --- | --- |
| 内容库、详情、原位编辑 | `grid.png`、`detail.png`、`edit.png` |
| 工作台、展开原文、手动填写 | `workbench.png`、`expanded.png`、`manual.png` |
| 新旧比较、失败保留、零勾选门槛 | `compare.png`、`failure.png`、`selectGate.png` |
| 最小尺寸及条目数量 | `minimumLibrary.png`、`minimumWorkbench.png`、`single.png`、`five.png` |
| 真实浏览器端点 | `live-compare.png`、`canvas-web.png` |

上述设计导出覆盖修正后外观；`live-compare.png` 与 `canvas-web.png` 是实际网页证据。`grid-first.png`、`detail-first.png` 属于早期过程，不用作最终画面对照。

## 验证边界

勾选与计数使用真实 Figma 变量；当前原型的文本、模型返回、错误、编辑、确认及保存结果均为预设 fixture。50 个画面展示流程和状态，不表示任意勾选子集、任意输入、逐条生成或批量保存已具有完整动态逻辑。原型不接受自由表单输入、不请求 DeepSeek、不读写 SQLite，也不执行真实剪贴板复制或系统插入。

本轮未改 Swift/AppKit 源码、已安装 v0.5.0、正式两库或 Keychain。仅有 Figma 与文档变更，未重跑 `python3 scripts/test-suite.py`；客户端、真实 API、数据库保存重启、失败恢复及跨应用插入须在后续获授权实现时重新验证。历史 V6 的测试通过不作为 V7 验收。
