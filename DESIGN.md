---
name: Prompt Injector
description: 原生深色内容工作台与快捷浮窗，保留经验、来源和 Prompt 的可读性。
colors:
  text: "#F4F4F2"
  secondary: "#A8A8A4"
  tertiary: "#92928F"
  focus: "rgb(76% 76% 76%)"
  error: "#FFAA9D"
  canvas: "#0B0B0B"
  shell: "#101010"
  panel: "#151515"
  band: "#1D1D1D"
  selection: "#292929"
  border: "#2B2B2B"
  shell-outline: "#3C3C3C"
  shell-outline-contrast: "#727272"
  editor-outline: "#626262"
  requirements: "#F5D975"
  coding: "#99A8FF"
  debugging: "#FFAA85"
  review: "#C5A0FF"
  release: "#F699C8"
  category-mint: "#74D5A8"
  category-cyan: "#71CDD9"
  category-lime: "#BEDA7B"
  category-ochre: "#D8B279"
  category-sky: "#79B7EE"
  category-rose: "#D999AF"
  category-sage: "#9EBBA6"
  category-taupe: "#B9A58F"
  category-olive: "#CED1A3"
  category-slate: "#AAAFCB"
typography:
  headline:
    fontFamily: system-ui
    fontSize: 26px
    fontWeight: 500
  preview-title:
    fontFamily: system-ui
    fontSize: 22px
    fontWeight: 500
  launcher-title:
    fontFamily: system-ui
    fontSize: 18px
    fontWeight: 500
    lineHeight: 26px
  row:
    fontFamily: system-ui
    fontSize: 14px
    fontWeight: 500
  management-card-title:
    fontFamily: system-ui
    fontSize: 17px
    fontWeight: 500
  body:
    fontFamily: system-ui
    fontSize: 13px
    fontWeight: 400
    lineHeight: 22px
  reading:
    fontFamily: system-ui
    fontSize: 15px
    fontWeight: 400
    lineHeight: 28px
  discussion-reply:
    fontFamily: system-ui
    fontSize: 16px
    fontWeight: 400
    lineHeight: 28px
  preview-reading:
    fontFamily: system-ui
    fontSize: 16px
    fontWeight: 400
    lineHeight: 32px
  preview-explanation:
    fontFamily: system-ui
    fontSize: 14px
    fontWeight: 400
    lineHeight: 28px
  label:
    fontFamily: system-ui
    fontSize: 12px
    fontWeight: 400
  caption:
    fontFamily: system-ui
    fontSize: 11px
    fontWeight: 400
  statistic:
    fontFamily: system-ui
    fontSize: 34px
    fontWeight: 600
  code:
    fontFamily: ui-monospace
    fontSize: 13px
    fontWeight: 400
    lineHeight: 22px
rounded:
  shell: 24px
  management: 20px
  panel: 16px
  document: 12px
  button: 10px
  field: 9px
  row: 10px
  segment: 7px
  checkbox: 4px
spacing:
  tight: 4px
  small: 8px
  control: 12px
  section: 16px
  panel-gap: 20px
  content-edge: 24px
  main-edge: 32px
components:
  action-outline:
    backgroundColor: transparent
    textColor: "{colors.text}"
    rounded: "{rounded.button}"
    size: 40px
  action-primary:
    backgroundColor: "{colors.selection}"
    textColor: "{colors.text}"
    rounded: "{rounded.button}"
    height: 40px
  category-row:
    textColor: "{colors.text}"
    typography: "{typography.row}"
    rounded: "{rounded.row}"
    height: 44px
  entry-row:
    textColor: "{colors.text}"
    typography: "{typography.row}"
    rounded: "{rounded.row}"
    height: 64px
  entry-row-compact:
    height: 80px
  management-row:
    textColor: "{colors.text}"
    typography: "{typography.row}"
    rounded: "{rounded.row}"
    height: 80px
  management-summary-card:
    backgroundColor: "{colors.shell}"
    textColor: "{colors.text}"
    typography: "{typography.management-card-title}"
    rounded: 14px
    height: 178px
  management-reading-panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text}"
    typography: "{typography.preview-reading}"
    rounded: "{rounded.panel}"
    padding: "24px 32px"
  management-reading-panel-compact:
    padding: "{spacing.content-edge}"
  segment-group:
    backgroundColor: "{colors.band}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.button}"
    padding: "{spacing.tight}"
  segment-selected:
    backgroundColor: "{colors.selection}"
    textColor: "{colors.text}"
    rounded: "{rounded.segment}"
  panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text}"
    rounded: "{rounded.panel}"
    padding: "{spacing.content-edge}"
  detail-document:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text}"
    rounded: "{rounded.document}"
    padding: "{spacing.section}"
  discussion-user:
    backgroundColor: "{colors.band}"
    textColor: "{colors.text}"
    typography: "{typography.reading}"
    rounded: "{rounded.document}"
    padding: "12px 16px"
  discussion-reply:
    textColor: "{colors.text}"
    typography: "{typography.discussion-reply}"
  experience-row:
    textColor: "{colors.text}"
    rounded: "{rounded.row}"
    height: 52px
  experience-workbench-row:
    textColor: "{colors.text}"
    typography: "{typography.reading}"
    rounded: "{rounded.row}"
    height: 70px
  experience-checkbox:
    rounded: "{rounded.checkbox}"
    size: 18px
  editor-field:
    backgroundColor: "{colors.shell}"
    textColor: "{colors.text}"
    rounded: "{rounded.field}"
    height: 44px
---

# Design System: Prompt Injector

## Overview

**Creative North Star: "原生深色内容工作台"**

安静的中性深黑外壳承载紧凑、清楚的内容工具。管理窗口让浏览、经验录入整理、长内容审核编辑和使用统计各有空间；快捷浮窗保持单窗三级调用。白色通用控件、灰色辅助信息与局部分类色建立层次，渐变 Logo 是贯穿两个窗口的识别资产。

本规范合并既有原生约定、Figma 移植与之后确认的界面精简；用户最新修订优先。系统字体、可选择正文、原生焦点和键盘行为继续服务于快速查找与调用；彩色柔光集中在 Logo、管理分类色点和浮窗分类文字。界面组成来自 [管理窗口 brief](docs/content-manager-brief.md)、[内容阅读 V2](docs/content-reading-v2.md)、[内容管理 V6](docs/content-management-v6.md) 与 [浮窗更新 brief](docs/launcher-refresh-brief.md)，授权和原型审核状态只在 [prototype.md](docs/prototype.md) 维护。

**当前记录依据（2026-11-04）：**对照 V6 授权、`ExperienceView.swift`、`PromptEditor.swift`、`ManagementWindow.swift` 与 `PageTransition.swift`，更新取消聊天、原文／Prompt 分区、手动并排录入、待保存列表和垃圾桶操作的说明。画面对照为 `artifacts/tests/20261103T163827.630468Z/ui/` 的新增、整理、手动、审核和作者原文八张默认／最小窗口截图，具体文件及构建与系统验证边界见 [V6 实施记录](docs/content-management-v6.md#原生实现-v050--2026-11-04)。本次延续既有视觉体系，全部前置 token 与 sidecar 保留；局部 shell 内容卡片不改变全局 panel。本轮未复验真实 API、跨应用插入或系统减少动态效果。

**V5 历史依据（2026-11-03）：**当时提取会话、审核和十五色循环的原生画面对照为 `artifacts/tests/20261102T161703.310103Z/ui/experience-chat.png`、`experience-minimum.png`、`experience-review.png`、`experience-original.png`；它们是两条经验 fixture，与 V5 Figma 的二十条示例分开记录。V5 默认／最小双栏参考为 `artifacts/conversation-v5/multi.png` 与 `minimum.png`，聊天布局已由 V6 替代。此前 V2 浏览、原文、说明及分类滚动依据 `artifacts/tests/20261101T044433.502881Z/ui/`；既有编辑与统计规范继续保留。历史真实 API 与系统验收边界见 [testing.md](docs/testing.md) 和 [实现记录](docs/experience-dialogue.md)。

**历史证据（2026-10-30）：**初版规范依据当日的 `Theme.swift`、`DesignUI.swift`、管理／编辑／统计／浮窗视图及本地 Design 资源提取。该轮对齐与图标修正的完整套件通过：52 项 Swift、7 项 Python 与 108 项原生检查，并留存 19 张新截图，报告为 `artifacts/tests/20261030T162746.795484Z/summary.json` 与 `ui/report.json`，构建 ID 为 `20261030T162750Z`，源码指纹为 `ffbe2067cbe2fae4e26a2103420947320e65bf8bba802c0090d440294c140bba`。独立视觉复核 SHIP，检查 `.impeccable/review/alignment/` 的全部 19 张有效截图；结论覆盖各尺寸浮窗、侧栏、编辑与统计的文字对齐，以及图标资源和打包结果。原生检查验证运行时与打包图标的透明外画布，源 PNG、10 张构建 PNG 与 ICNS 的 alpha 检查留在 `artifacts/alignment/icon-alpha.log`；八张打包位图均有来源记录。此前正常应用已通过系统绿色按钮进入独立 Space 全屏；该轮已重启至上述构建并打开现有内容库。Dock 的实际系统外观未取得截图，真实跨应用输入框插入也未在该轮版本复验，不将这些边界算作该轮视觉通过。最新进度见 [移植记录](docs/figma-integration.md)。前置 token 的 CSS px 在 AppKit 中对应同数值的逻辑 pt；侧车 HTML/CSS 仅供设计面板预览，不模拟 AppKit 的排版、焦点环或系统阴影；侧车八级 OKLCH 梯度是合成展示色，不是原生颜色 token。

**Key Characteristics:**

- 中性深黑底、炭灰面板与低对比细边界。
- 白色通用控件；分类语义色按具体界面使用。
- 渐变 Logo、管理分类柔光色点与浮窗分类文字柔光。
- 系统比例字体、可选择正文、原生键盘与辅助功能行为。

## Colors

中性层次组织界面，分类色负责识别和统计数据，不替代通用操作的白色文字与图标。

### Primary

- **通用操作白**（`text`）：导航、按钮、选中页签和时段文字；主要按钮使用 `selection` 深灰底，不使用旧版亮色实心插入样式。
- **中性焦点**（`focus`）：延续原生焦点语义，不作为分类或品牌色。
- **失败反馈**（`error`）：保存、复制或插入失败时使用，不作为常态装饰。
- **渐变 Logo**：运行时优先加载 [Logo.png](macOS/PromptInjector/Resources/Design/Logo.png) 的 3 倍透明导出以保留柔光，[Logo.svg](macOS/PromptInjector/Resources/Design/Logo.svg) 留作原始矢量源。保持批准稿的轮廓、五色渐变与同形柔光，不以近似渐变或系统图标重画；渐变停止点由资源文件持有，不再另建一份色值表。

### Secondary

- **需求暖黄**（`requirements`）、**编码淡蓝**（`coding`）、**排查珊瑚**（`debugging`）、**审查淡紫**（`review`）、**发布粉色**（`release`）：保留原五色及其顺序，名称仅保留初始种子的历史含义，不按分类 ID 固定。
- 第六至十五色依次为 **薄荷绿**（`category-mint`）、**浅青**（`category-cyan`）、**嫩黄绿**（`category-lime`）、**柔赭**（`category-ochre`）、**天蓝**（`category-sky`）、**灰玫瑰**（`category-rose`）、**鼠尾草绿**（`category-sage`）、**灰褐**（`category-taupe`）、**浅橄榄**（`category-olive`）、**灰蓝紫**（`category-slate`）。与原五色组成十五色循环，第十六类回到第一色；分类名称来自 SQLite，不因扩色新增分类或设置项。
- 管理窗口的侧栏分类名及预览分类名使用对应彩色文字；预览只显示分类名称，条目列表不再重复分类元信息。侧栏、编辑选择器、趋势图图例和分类分布保留对应柔光色点。编辑选择器文字、趋势图图例和分布名称保持中性；统计曲线、面积与占比条使用分类色。
- 浮窗不出现分类色点；第一层分类名及后续页顶部当前分类名使用对应彩色文字和柔光。条目标题、简述、数量及操作仍是中性色。

### Neutral

- `canvas`、`shell`、`panel`、`band`、`selection`：从主背景、侧栏／浮窗外壳、内容面、横向操作条到选中状态逐层提亮。
- `secondary`、`tertiary`：简述、说明、数量、来源与快捷键提示；辅助数量保持灰色。
- `border`：面板、输入框、细分隔线与轮廓按钮边界；`editor-outline` 用于长内容编辑面板。浮窗外边线使用 `shell-outline`，提高对比度时改用 `shell-outline-contrast`。

**The Neutral Controls Rule.** 通用导航、按钮、选中页签与时段使用深灰底和白色文字／图标；分类色只进入上述明确的分类与数据位置。

**The Shared Category Order Rule.** 侧栏、编辑器、预览、浮窗和统计均按 SQLite 的完整分类顺序取循环色，不按当前筛选结果重新编号；名称始终保留，颜色不作为唯一标识。

## Typography

**Display / Body Font:** `NSFont.systemFont`。**Code Font:** `NSFont.monospacedSystemFont`，仅浮窗 Prompt 的围栏代码段使用。

客户端使用系统字体是有意选择。Figma 中 Inter 与 Noto Sans SC 是解决预览导出缺字的表达方式，不要求在客户端嵌入这些字体。普通中文、英文说明和 Prompt 段落继续使用比例字体。

- `headline` 用于管理页与统计页标题；`preview-title` 用于管理预览标题；`launcher-title` 用于浮窗详情标题。
- `row` 用于条目标题与浮窗分类；管理预览分类为 13 pt 中等字重，管理侧栏名称为 13 pt 常规字重。品牌标题为 15 pt 半粗体，局部区块标题为 16 pt 中等字重。
- `body` 是浮窗正文基线；`reading` 用于编辑器长文本，均保持比例字体。`discussion-reply` 保留为历史 token，V6 不再展示聊天回复。管理简述编辑使用 13 pt／24 pt 行高。
- `preview-reading` 用于管理预览的 Prompt 与作者原文；`preview-explanation` 仅用于独立的整理说明页。原文页的来源为 13 pt／24 pt 行高，HTTP／HTTPS 链接保留原生点击能力。
- `label`、`caption` 和 `statistic` 分别用于辅助标签、弱提示和统计大数值。字段标签可用中等字重，不将全部辅助信息加粗。

需要居中的标签与列表文字由 `Theme.placeLine` 结合 CoreText 可见字形边界及原生 `firstBaselineOffsetFromTop` 放置，兼容翻转和非翻转容器；不用控件框高度推测可见文字中心。搜索、标题和来源等单行可编辑字段使用稳定的字体基线，输入字符变化时不跳动。侧栏与统计图例、分布文字由 `Theme.drawLine` 按可见字形居中绘制；统计排行的 `UsageTableCell` 在每次布局时居中标签。

浮窗详情标题最多两行；正文按字符换行并在内部滚动。Prompt 围栏在浮窗显示时转为代码样式，复制仍读取完整原始字段，保留围栏和换行。

## Layout

管理窗口与浮窗共用色彩、组件和间距语言，保留各自的原生窗口与滚动结构。

### Management

初始窗口 1440 × 960 pt，最小 1100 × 720 pt；启动时按可用屏幕范围收敛。侧栏固定 216 pt，主区从 x = 248 pt 开始，右侧留 32 pt。侧栏主导航与分类由分隔线分组；分类整行高 44 pt、行间距 10 pt，无逐行外框。管理窗口使用系统 `.titled`、`.fullSizeContentView`、`.closable`、`.miniaturizable` 与 `.resizable` 样式，标题栏透明、标题文字隐藏。左侧栏顶部留出空白放置系统提供的红黄绿按钮；关闭前完成草稿保存，再隐藏窗口。管理窗口以 `.fullScreenPrimary` 加入独立 Space，支持系统绿色按钮及 `⌃⌘F` 进入／退出原生全屏。打开管理窗口时应用切为常规 macOS 应用并使用自家 AppIcon，Dock 重开动作返回管理窗口。

内容浏览页的标题、搜索和加号在同一行，主体从 y = 112 pt 开始，底部留 32 pt。列表与预览间隔 20 pt：主体宽度至少 1100 pt 时列表 352 pt，否则 280 pt。列表只显示标题与一行简述，行高由 `management-row` 定义，间距 4 pt；去掉重复分类元信息。预览默认只显示 Prompt，页签「Prompt / 作者原文 / 整理说明」独立切换；作者原文保留原字句和来源链接，复制始终复制完整 Prompt。预览左右留白在主体宽度至少 1100 pt 时用 `main-edge`，否则用 `content-edge`；标题最多两行，简述为 13 pt、最多两行，完整文字可从 tooltip 与编辑器读取。三个阅读页正文最大宽度均为 640 pt，各自使用 Typography 中的阅读层级；切换条目重回 Prompt，切换阅读页回到正文顶部。复制／编辑固定底部。分类区域独立纵向滚动，全部内容／统计和底部快捷键不随分类移动。

经验录入与整理页主体从 y = 112 pt 开始，底部保留状态与 API key 配置入口。新增页用一张内容卡片录入原文或链接，并保留可选来源、「整理」与「手动填写」。手动填写在同一卡片内并排放原文和 Prompt，直接粘贴后继续审核。多条整理时左列宽度为主区宽度的 34%、最多 352 pt，与右列间隔 20 pt；左列底部固定勾选数量和「审核已勾选」。右侧上方只读当前作者原文，下方独立编辑 Prompt；「DeepSeek 生成」放在 Prompt 标题旁。列表、作者原文和 Prompt 各自滚动，不再显示聊天消息或发送框。

审核页复用编辑器：默认左列 352 pt，主区不足 1100 pt 时 320 pt，列间隔 20 pt。左列只列待保存条目的标题和简述，点选切换；右列顶部集中标题、分类、简述与按需出现的新分类名称，下方以「Prompt / 作者原文 / 整理说明」分开阅读和编辑。顶部显示「返回整理」与明确的保存数量，不显示上一条／下一条。长内容独立滚动，作者原句和来源只读。

普通编辑页仍保留 64 pt 横向操作条，主体从 y = 192 pt 开始。

编辑页左列放标题、分类、简述与来源，右列放长文本；主区宽度至少 1100 pt 时左列 380 pt，否则 320 pt，两列间隔 20 pt。保存与取消固定于顶部，未保存／草稿／失败状态就近显示。左侧元信息与右侧正文各自滚动。

统计页在主区整体纵向滚动，文档最低高度为常态 980 pt、错误反馈时 1020 pt。页头左侧是标题与日期，时段分段位于右上 y = 32 pt；四个指标从 y = 112 pt 开始，趋势图从 y = 260 pt 开始，排行和分类分布从 y = 580 pt 开始。指标间隔 16 pt，主要面板间隔 20 pt。指标辅助值只保留实际日均与百分比等数字，不显示解释条或常态页脚。统计内容使用本地成功动作记录，零记录显示真实空状态。主滚动区关闭自动内容 inset，保持与其他管理页面相同的顶部位置；排行行高 38 pt，单元格间距为零，标题列与数值列跟随各自表头对齐。

### Launcher

单窗三级导航，初始 620 × 520 pt，最小 360 × 300 pt。固定顶部和底部，中间滚动；窗口宽度小于 450 pt 时左右留白从 24 pt 收到 16 pt，条目行高从 64 pt 增为 80 pt，简述允许两行。`PromptCell` 的紧凑状态直接由窗口宽度传入，不以原生表格给出的单元格高度判断。分类行高 44 pt，浮窗列表行间距 8 pt。

第一层显示 Logo 和品牌名，后续页显示返回与当前分类；不显示目标应用标签。顶部高度为 56 pt，紧凑时 52 pt；底部常态为 60 pt，紧凑时 56 pt，错误时扩到 104 pt。详情不重复显示顶部来源行，完整来源仍在“经验与来源”中可读。

详情在标题下提供“Prompt / 经验与来源”分段，Prompt 默认打开。正文只使用一个面板，原始经验、来源、解释之间用细线区隔；空字段隐藏，正文内部滚动。

## Elevation & Depth

内部以纯色面板、低对比细边界和状态提亮表达层次，不给每个容器加阴影。两个窗口保留 macOS 系统窗口阴影。浮窗仍有 HUD／behind-window 材质视图，但当前中性 `shell` 遮罩是不透明色，不再使用旧版偏暖透明配方；降低透明度时隐藏底层材质，提高对比度时增强外边线。

Logo 与原五色管理分类点优先加载本地 3 倍透明 PNG，因为 AppKit 的 SVG 渲染会忽略稿件中的 blur filter；原始 SVG 保留为矢量依据，其他控件继续直接使用 SVG。Logo 原稿为同形副本透明度 0.55、Gaussian blur 标准差 3；色点原稿为 7 pt 亮芯与 27 × 27 pt 完整外延，含两层柔光（标准差 1.5／5，透明度 0.9／0.65）。这些效果由 PNG 预渲染保留，原生不再重复叠加，布局不得裁掉外缘。Logo 与原五色资源的逻辑尺寸从 PNG bitmap 像素宽高除以 3 取得，不能使用 PNG DPI 元数据推测逻辑尺寸。第六至十五色由 `DesignAssets.categoryDot` 按同样 27 pt 外延、7 pt 亮芯绘制，使用透明度 0.6、blur 7 pt 的零偏移原生阴影；不存在十五份 PNG 资源。浮窗分类文字继续由 `Theme.glow` 叠加文字阴影（透明度 0.55、blur 3 pt）与 layer 柔光（opacity 0.28、radius 9 pt），偏移均为零。

**The Scoped Glow Rule.** 柔光只强调 Logo 和明确的分类标识，不扩展到通用按钮、面板或正文。

浮窗动效沿用既有原生实现：出现从 97.5% 舒展到完整尺寸并在 0.18 秒内淡入；隐藏回收到 98.5%，在 0.12 秒内淡出。页面前进／返回分别在 0.18／0.16 秒内从左右 16 pt 移入，旧内容反向移动 10 pt 并在 0.12 秒内淡出。页面切换只作用于中间内容，材质、页头与底部静止。进入使用 `cubic-bezier(0.16, 1, 0.3, 1)`；关闭淡出使用系统 ease-in。减少动态效果时立即切换，插入交接焦点时立即隐藏。

动效不得修改保存的窗口几何；稳定显示 alpha 为 1。连续开关中断旧动效并正确反向，旧关闭回调不得隐藏新打开的窗口；导航、缩放与隐藏清理旧快照，保留选择和滚动。透明快照不接收点击或辅助功能焦点。

管理窗口的页面进入使用 0.18 秒淡化，返回内容管理使用 0.14 秒；阅读分页与当前经验切换使用 0.12 秒淡化，均为 ease-out。选择、勾选和输入即时更新；复用 `PageTransition.fade`，系统减少动态效果开启时跳过过渡，不新增开关。这是实现参数，不能代替系统设置实测或帧率验收。

## Shapes

外壳使用连续圆角，管理根视图、内部面板、详情正文、按钮和输入框依次采用前置 token 中的轮廓。面板与轮廓按钮边界为 1 pt，分隔线也为 1 pt；侧栏分类通过整行点击区和选中底色组织，不绘制重复小框。

Logo 的逻辑槽位在管理侧栏为 32 pt、浮窗为 24 pt。当前 Logo PNG 为 112 × 124 像素；32 pt 槽位中的图像框为 112/3 × 124/3 pt，x = 0、y = −5.261 pt，其他槽位按宽度同比缩放。原五色分类点 PNG 均为 81 × 81 像素，显示为 27 × 27 pt；新增十色使用同尺寸的原生绘制图像，均相对 7 pt 槽位向左／上各外扩 10 pt。菜单栏使用独立单色模板图标，36 像素资源显示为 18 逻辑 pt，由系统着色；不把彩色 Logo 当菜单栏模板。八个打包 PNG 均保留 `impeccable:prompt` 来源元数据，Figma 导出的七张另保留 `Software`；应用图标和资源说明见 [Design 资源说明](macOS/PromptInjector/Resources/Design/README.md)。

应用图标 `AppIcon.png` 保留黑色圆角底块和原有彩色品牌，只用内置 imagegen 去除底块外的白色画布；精确编辑提示保存在 PNG 元数据中。当前透明源为 1254 × 1254 像素，运行时应用图标和 ICNS 共用这张源图，打包通过系统 `sips`／`iconutil` 生成 16–1024 像素规格。界面 Logo 与菜单栏模板维持各自资源，不随应用图标改动。

装饰边界、Logo 和柔光不拦截正文选择、按钮点击或边缘缩放。

## Components

### Buttons

复制、编辑、插入和管理预览删除统一为透明底、细灰边、白色图标的 40 × 40 pt 按钮；浮窗只在详情显示复制和插入。删除使用垃圾桶图标，保留「删除条目」tooltip 与「删除当前条目」可访问名称。管理新建为深灰填充、白色加号的 40 × 40 pt 纯图标按钮，保留“新建条目” tooltip 与可访问名称；保存仍使用带文字的主要操作。主要操作悬停／按下依次提亮；透明操作悬停使用 6% 白，按下使用 12% 白。主要／选中按钮常态为 `selection`，悬停为 #323232，按下为 #353535。禁用图标使用 `tertiary`。

图标来自本地 Figma SVG，未映射项才回退 SF Symbols。保留 tooltip、可访问名称和 `ActionButton` 的 AppKit exterior 焦点环。返回／关闭的点击区为 32 pt，不误套底部动作尺寸。

### Navigation

浮窗第一层只显示分类名、数量和箭头；第二层只显示标题、简述和箭头；第三层再加载正文。悬停使用 `band`，选中使用 `selection`。管理侧栏导航与分类保持完整行点击区，数量弱化；列表与详情分别滚动。

全局快捷键、Return、Shift + Return、Escape、详情 `⌘Return` 的约定继续见 [launcher-brief.md](docs/launcher-brief.md)。隐藏再显示保留页面、滚动和选择。移除目标标签不改变唤起时捕获目标、插入前重新确认及失败时保留复制的行为；插入只填写，不发送。

### Segmented Views

`ChoiceSegments` 使用 `band` 底色、4 pt 内边距、4 pt 按钮间隙；选中片使用更小圆角和 `selection`，文字为白色，未选为辅助灰。管理浏览页的三页阅读分段与编辑页均高 44 pt，浮窗详情高 34 pt，统计时段高 40 pt。分段使用原生按钮，选中状态提供辅助功能值。

### Panels and Documents

`SurfaceView` 默认是 `panel` 底、细灰边的安静容器；横向操作条使用 `band` 且不描边。管理预览与浮窗正文可选择，完整复制始终读取原始 Prompt；不从屏幕拼接被截断的文本。浮窗“经验与来源”保留独立字段与分隔线，不拆成四张重复卡片。

V6 管理列表、预览、整理和审核内容卡片局部使用 `shell`，让左右区域保持同色；Prompt 编辑区继续保留 `editor-outline`。这是内容卡片的局部使用规则，全局 `panel` 和弹层不随之改色。

### Inputs and Editor

搜索框只搜索标题与简述，高 40 pt，使用低对比深色背景、灰边、搜索图标与占位提示。标题／分类／来源字段高 44 pt；长文本通过原生 `NSTextView` 编辑，支持撤销、白色插入光标与独立滚动。输入控件边界维持中性，编辑主面板使用较清楚的 `editor-outline`，不以分类色描边。

保存状态放在顶部操作条，必填和保存错误就近显示；常态不重复提示必填规则，也不附加作者或格式说明。失败保留输入、草稿与重试能力；视觉成功状态不能先于本地保存成功。管理表单的长内容不移入快捷浮窗。

### Experience Entry and Review

V6 取消聊天，原文／链接一键整理。每条经验分开保留只读作者原文与可编辑 Prompt；用户可以手贴、修改，或明确点击「DeepSeek 生成」。切换经验按稳定 ID 恢复各条 Prompt，已有内容重新生成先确认替换；进入审核不自动请求模型。手动填写入口并排录入原文与 Prompt，来源可选。

经验列表行高 52 pt、行间距 4 pt；当前经验行使用 `selection` 与 `row` 圆角。文字只切换当前条；18 pt 方框位于 44 pt 点击区中，只更新勾选与计数，不切换当前条。文字为 15 pt 系统字体，完整标题由 tooltip 保留；勾选态提供复选框辅助功能角色和值。当前条高亮与勾选分别表达两种状态；已勾选条目有空 Prompt 时明确提示并阻止审核。

审核沿用现有字段和分段。标题、分类、简述、Prompt 和整理说明可编辑，作者原文与来源只读；点左侧待保存条目切换前保留当前修改。保存数量来自当前勾选，事务成功后才显示成功。来源标识使用本地 `SourceX.svg`、`SourceGitHub.svg`、`SourceReddit.svg` 的 16 pt 模板图标，其他来源回退链接符号；来源入口保留完整来源 tooltip。垃圾桶位于已有条目预览的操作区，确认弹窗点名待删标题并提供取消；不以划过或选中条目触发删除。

### V7 Summary Cards and Workbench

V7 是既有深色体系的局部延伸，采用以下组件；前述 V6 录入／审核记录保留作历史对照，不作为 V7 的布局约定。全局颜色、字体家族、面板、控件与十五色顺序继续沿用。

`management-summary-card` 用于内容库摘要卡片，使用 `shell`、细灰边与局部圆角；选中时只提亮边界，不增加抬升或面板柔光。标题采用 `management-card-title`、最多两行，简述沿用 `body` 的字体与辅助灰；顶部保留分类名称和既有分类柔光点，来源操作独立于打开卡片。卡片间距采用 `section`，网格实际内容宽度至少 1000 pt 时三列，否则两列；高度与圆角由前置组件 token 定义。点按或对选中卡片按 Return 后才加载完整正文。

已有条目阅读和原位编辑复用同一列表／详情容器，保留分类、搜索、稳定 ID 和网格滚动。紧凑编辑器把标题／分类并排、简述置下，随后是阅读分段和大正文；保存／取消留在编辑区域底部，不增加独立编辑页面。

单条和多条经验共用工作台：左列最多 300 pt，与右侧紧凑编辑器间隔 `panel-gap`；原文可折叠、来源独立只读，Prompt 占主要编辑区域。`experience-workbench-row` 比历史经验行多一行 `caption` 状态；标题沿用 `reading` 字体，当前条使用 `selection`，复选框沿用 `experience-checkbox` 和原有 44 pt 点击区。点文字只切换查看，勾选只决定批量生成集合，人工确认是独立操作；修改已确认内容会恢复待确认。状态和剩余数量由实际条目驱动，部分保存后继续留在同一工作台。

本节依据 `ManagementGrid.swift`、`ExperienceView.swift` 与 `PromptEditor.swift`，并对照 `.impeccable/review/v7-port/` 中的 `management-library.png`、`management-grid-minimum.png`、`management-inline-editor.png` 和 `experience-organize.png`。实现与本轮既有测试报告见 [V7 原生移植记录](docs/management-v7-implementation.md)；本次文档补录没有重跑客户端、真实 API、Codex 插入、VoiceOver 或 Reduce Motion。侧车新增组件仅是静态预览，不替代原生焦点、分类柔光资源或状态逻辑。

### Feedback

连续处理沿用 V7 双栏：左栏标题旁放「＋ 添加经验」，新增在右栏复用原文／链接和手动表单，左栏仍可切回现有条目。当前草稿的中性垃圾桶与生成操作同行，列表右键提供同一动作；仅保护手改内容时确认。零条时去掉列表和编辑空面板，只显示状态及「继续添加／查看内容库」。

管理详情复制、编辑、删除均采用既有 40 × 40 pt 描边图标按钮，保留 tooltip、辅助功能名称和焦点；复制成功原位短暂换勾。正式删除仍使用默认取消的中性确认框。

常态界面保留内容、字段、数量、操作名称和快捷键；品牌副标题、重复筛选名称、本地保存／可调用说明、示例来源说明与静态页脚不占用页面空间。空状态、失败原因、保存／草稿状态、操作 tooltip 和快捷键提示继续保留；移除说明文字不删除原始经验、来源、解释或 Prompt 数据。

浮窗成功提示显示 2 秒，常规错误显示 8 秒；需要用户处理的插入错误持续显示并保留复制，缺权限时提供权限入口。目标、权限或写入校验失败以明确的错误类型锁住插入，按钮与 `⌘Return` 共用同一门禁；仅在重新唤起并捕获到有效新目标后解除，同时清除旧错误反馈。剪贴板写入失败或仍按住快捷键属于可重试错误，不锁住新一次尝试。错误可换行并扩展底部高度，避免遮挡动作；反馈同步发出辅助功能公告。统计记录失败与已完成的复制／插入区分呈现，不用失败统计撤销已完成动作的事实。

## Do's and Don'ts

### Do:

- **Do** 使用系统字体、原生红黄绿按钮与独立 Space 全屏、应用 Logo、文字选择和明确的可访问名称。
- **Do** 让通用控件保持中性白／深灰，所有界面按同一完整分类顺序循环十五色，保留前五色。
- **Do** 让管理预览只显示对齐的分类名称，在侧栏、编辑器和统计中保留分类色点；浮窗只使用分类文字柔光。
- **Do** 复用本地资源：Logo／原五色色点使用 3 倍 PNG 保留柔光和正确逻辑尺寸，新增十色使用同尺寸原生色点，SVG 保留为矢量来源。
- **Do** 尊重降低透明度、提高对比度与减少动态效果设置。
- **Do** 为长内容保留滚动、完整复制及保存失败后的编辑内容。

### Don't:

- **Don't** 重新采用已否决的浅色稿、旧版暖灰配方或亮色实心插入按钮。
- **Don't** 给管理预览加回分类色点，或给浮窗加分类色点和目标应用标签。
- **Don't** 添加重复的来源标题、筛选名称或无助于当前操作的常态说明。
- **Don't** 把通用按钮、编辑边界和所有统计标签染成分类色。
- **Don't** 把详情拆成四张重复卡片，或把普通正文全部改成等宽。
- **Don't** 用 Figma、HTML/CSS 预览或源码参数代替真实画面对照与原生验收。
- **Don't** 绕过插入失败门禁，或用界面成功状态代替保存成功与真实输入框写入确认。
