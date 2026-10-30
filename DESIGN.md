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
typography:
  headline:
    fontFamily: system-ui
    fontSize: 26px
    fontWeight: 500
  preview-title:
    fontFamily: system-ui
    fontSize: 24px
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
    height: 84px
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
  editor-field:
    backgroundColor: "{colors.shell}"
    textColor: "{colors.text}"
    rounded: "{rounded.field}"
    height: 44px
---

# Design System: Prompt Injector

## Overview

**Creative North Star: "原生深色内容工作台"**

安静的中性深黑外壳承载紧凑、清楚的内容工具。管理窗口让浏览、长内容编辑和使用统计各有空间；快捷浮窗保持单窗三级调用。白色通用控件、灰色辅助信息与局部分类色建立层次，渐变 Logo 是贯穿两个窗口的识别资产。

本规范合并既有原生约定、Figma 移植与之后确认的界面精简；用户最新修订优先。系统字体、可选择正文、原生焦点和键盘行为继续服务于快速查找与调用；彩色柔光集中在 Logo、管理分类色点和浮窗分类文字。界面组成来自 [管理窗口 brief](docs/content-manager-brief.md) 与 [浮窗更新 brief](docs/launcher-refresh-brief.md)，授权和原型审核状态只在 [prototype.md](docs/prototype.md) 维护。

**证据边界：**本规范依据 2026-10-30 的 `Theme.swift`、`DesignUI.swift`、管理／编辑／统计／浮窗视图及本地 Design 资源提取。本次对齐与图标修正的完整套件通过：52 项 Swift、7 项 Python 与 108 项原生检查，并留存 19 张新截图，报告为 `artifacts/tests/20261030T162746.795484Z/summary.json` 与 `ui/report.json`，构建 ID 为 `20261030T162750Z`，源码指纹为 `ffbe2067cbe2fae4e26a2103420947320e65bf8bba802c0090d440294c140bba`。独立视觉复核 SHIP，检查 `.impeccable/review/alignment/` 的全部 19 张有效截图；结论覆盖各尺寸浮窗、侧栏、编辑与统计的文字对齐，以及图标资源和打包结果。原生检查验证运行时与打包图标的透明外画布，源 PNG、10 张构建 PNG 与 ICNS 的 alpha 检查留在 `artifacts/alignment/icon-alpha.log`；八张打包位图均有来源记录。此前正常应用已通过系统绿色按钮进入独立 Space 全屏；本次已重启至上述构建并打开现有内容库。Dock 的实际系统外观未取得截图，真实跨应用输入框插入也未在本次版本复验，不将这些边界算作本轮视觉通过。最新进度见 [移植记录](docs/figma-integration.md)。前置 token 的 CSS px 在 AppKit 中对应同数值的逻辑 pt；侧车 HTML/CSS 仅供设计面板预览，不模拟 AppKit 的排版、焦点环或系统阴影；侧车八级 OKLCH 梯度是合成展示色，不是原生颜色 token。

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

- **需求暖黄**（`requirements`）、**编码淡蓝**（`coding`）、**排查珊瑚**（`debugging`）、**审查淡紫**（`review`）、**发布粉色**（`release`）：五个固定分类共用同一映射。
- 管理窗口的侧栏分类名、条目元信息及预览分类名使用对应彩色文字；预览只显示分类名称，侧栏、编辑选择器、趋势图图例和分类分布保留对应柔光色点。编辑选择器文字、趋势图图例和分布名称按当前稿保持中性；统计曲线、面积与占比条使用分类色。
- 浮窗不出现分类色点；第一层分类名及后续页顶部当前分类名使用对应彩色文字和柔光。条目标题、简述、数量及操作仍是中性色。

### Neutral

- `canvas`、`shell`、`panel`、`band`、`selection`：从主背景、侧栏／浮窗外壳、内容面、横向操作条到选中状态逐层提亮。
- `secondary`、`tertiary`：简述、说明、数量、来源与快捷键提示；辅助数量保持灰色。
- `border`：面板、输入框、细分隔线与轮廓按钮边界；`editor-outline` 用于长内容编辑面板。浮窗外边线使用 `shell-outline`，提高对比度时改用 `shell-outline-contrast`。

**The Neutral Controls Rule.** 通用导航、按钮、选中页签与时段使用深灰底和白色文字／图标；分类色只进入上述明确的分类与数据位置。

## Typography

**Display / Body Font:** `NSFont.systemFont`。**Code Font:** `NSFont.monospacedSystemFont`，仅浮窗 Prompt 的围栏代码段使用。

客户端使用系统字体是有意选择。Figma 中 Inter 与 Noto Sans SC 是解决预览导出缺字的表达方式，不要求在客户端嵌入这些字体。普通中文、英文说明和 Prompt 段落继续使用比例字体。

- `headline` 用于管理页与统计页标题；`preview-title` 用于管理预览标题；`launcher-title` 用于浮窗详情标题。
- `row` 用于条目标题、浮窗分类及管理预览分类名；预览分类采用 14 pt 中等字重，管理侧栏名称为 13 pt 常规字重。品牌标题为 15 pt 半粗体，局部区块标题为 16 pt 中等字重。
- `body` 是浮窗正文基线；`reading` 用于管理预览 Prompt 与长文本编辑。管理简述编辑使用 13 pt／24 pt 行高，其他长文本为 15 pt／28 pt 行高。
- `label`、`caption` 和 `statistic` 分别用于辅助标签、弱提示和统计大数值。字段标签可用中等字重，不将全部辅助信息加粗。

需要居中的标签与列表文字由 `Theme.placeLine` 结合 CoreText 可见字形边界及原生 `firstBaselineOffsetFromTop` 放置，兼容翻转和非翻转容器；不用控件框高度推测可见文字中心。搜索、标题和来源等单行可编辑字段使用稳定的字体基线，输入字符变化时不跳动。侧栏与统计图例、分布文字由 `Theme.drawLine` 按可见字形居中绘制；统计排行的 `UsageTableCell` 在每次布局时居中标签。

浮窗详情标题最多两行；正文按字符换行并在内部滚动。Prompt 围栏在浮窗显示时转为代码样式，复制仍读取完整原始字段，保留围栏和换行。

## Layout

管理窗口与浮窗共用色彩、组件和间距语言，保留各自的原生窗口与滚动结构。

### Management

初始窗口 1440 × 960 pt，最小 1100 × 720 pt；启动时按可用屏幕范围收敛。侧栏固定 216 pt，主区从 x = 248 pt 开始，右侧留 32 pt。侧栏主导航与分类由分隔线分组；分类整行高 44 pt、行间距 10 pt，无逐行外框。管理窗口使用系统 `.titled`、`.fullSizeContentView`、`.closable`、`.miniaturizable` 与 `.resizable` 样式，标题栏透明、标题文字隐藏。左侧栏顶部留出空白放置系统提供的红黄绿按钮；关闭前完成草稿保存，再隐藏窗口。管理窗口以 `.fullScreenPrimary` 加入独立 Space，支持系统绿色按钮及 `⌃⌘F` 进入／退出原生全屏。打开管理窗口时应用切为常规 macOS 应用并使用自家 AppIcon，Dock 重开动作返回管理窗口。

内容页与编辑页固定标题和 64 pt 高横向操作条，主体从 y = 192 pt 开始。浏览页为列表与预览两列，间隔 20 pt：主体宽度至少 1100 pt 时列表为 420 pt，否则取主体的 36% 且不小于 280 pt。列表行高 84 pt、行间距 4 pt，元信息只显示分类名称。预览分类名、标题与正文共用 24 pt 左边缘，分类名不带色点；Prompt 独立滚动，复制／编辑固定在底部。预览顶部不重复来源，完整原始经验、来源与解释仍可从“原文与来源”和编辑页访问。

编辑页左列放标题、分类、简述与来源，右列放长文本；主区宽度至少 1100 pt 时左列 380 pt，否则 320 pt，两列间隔 20 pt。保存与取消固定于顶部，未保存／草稿／失败状态就近显示。左侧元信息与右侧正文各自滚动。

统计页在主区整体纵向滚动，文档最低高度为常态 980 pt、错误反馈时 1020 pt。页头左侧是标题与日期，时段分段位于右上 y = 32 pt；四个指标从 y = 112 pt 开始，趋势图从 y = 260 pt 开始，排行和分类分布从 y = 580 pt 开始。指标间隔 16 pt，主要面板间隔 20 pt。指标辅助值只保留实际日均与百分比等数字，不显示解释条或常态页脚。统计内容使用本地成功动作记录，零记录显示真实空状态。主滚动区关闭自动内容 inset，保持与其他管理页面相同的顶部位置；排行行高 38 pt，单元格间距为零，标题列与数值列跟随各自表头对齐。

### Launcher

单窗三级导航，初始 620 × 520 pt，最小 360 × 300 pt。固定顶部和底部，中间滚动；窗口宽度小于 450 pt 时左右留白从 24 pt 收到 16 pt，条目行高从 64 pt 增为 80 pt，简述允许两行。`PromptCell` 的紧凑状态直接由窗口宽度传入，不以原生表格给出的单元格高度判断。分类行高 44 pt，浮窗列表行间距 8 pt。

第一层显示 Logo 和品牌名，后续页显示返回与当前分类；不显示目标应用标签。顶部高度为 56 pt，紧凑时 52 pt；底部常态为 60 pt，紧凑时 56 pt，错误时扩到 104 pt。详情不重复显示顶部来源行，完整来源仍在“经验与来源”中可读。

详情在标题下提供“Prompt / 经验与来源”分段，Prompt 默认打开。正文只使用一个面板，原始经验、来源、解释之间用细线区隔；空字段隐藏，正文内部滚动。

## Elevation & Depth

内部以纯色面板、低对比细边界和状态提亮表达层次，不给每个容器加阴影。两个窗口保留 macOS 系统窗口阴影。浮窗仍有 HUD／behind-window 材质视图，但当前中性 `shell` 遮罩是不透明色，不再使用旧版偏暖透明配方；降低透明度时隐藏底层材质，提高对比度时增强外边线。

Logo 与管理分类色点优先加载本地 3 倍透明 PNG，因为 AppKit 的 SVG 渲染会忽略稿件中的 blur filter；原始 SVG 保留为矢量依据，其他控件继续直接使用 SVG。Logo 原稿为同形副本透明度 0.55、Gaussian blur 标准差 3；色点原稿为 7 pt 亮芯与 27 × 27 pt 完整外延，含两层柔光（标准差 1.5／5，透明度 0.9／0.65）。这些效果由 PNG 预渲染保留，原生不再重复叠加，布局不得裁掉外缘。Logo 与五个色点的逻辑尺寸从 PNG bitmap 像素宽高除以 3 取得，不能使用 PNG DPI 元数据推测逻辑尺寸。浮窗分类文字继续由 `Theme.glow` 叠加文字阴影（透明度 0.55、blur 3 pt）与 layer 柔光（opacity 0.28、radius 9 pt），偏移均为零。

**The Scoped Glow Rule.** 柔光只强调 Logo 和明确的分类标识，不扩展到通用按钮、面板或正文。

浮窗动效沿用既有原生实现：出现从 97.5% 舒展到完整尺寸并在 0.18 秒内淡入；隐藏回收到 98.5%，在 0.12 秒内淡出。页面前进／返回分别在 0.18／0.16 秒内从左右 16 pt 移入，旧内容反向移动 10 pt 并在 0.12 秒内淡出。页面切换只作用于中间内容，材质、页头与底部静止。进入使用 `cubic-bezier(0.16, 1, 0.3, 1)`；关闭淡出使用系统 ease-in。减少动态效果时立即切换，插入交接焦点时立即隐藏。

动效不得修改保存的窗口几何；稳定显示 alpha 为 1。连续开关中断旧动效并正确反向，旧关闭回调不得隐藏新打开的窗口；导航、缩放与隐藏清理旧快照，保留选择和滚动。透明快照不接收点击或辅助功能焦点。

## Shapes

外壳使用连续圆角，管理根视图、内部面板、详情正文、按钮和输入框依次采用前置 token 中的轮廓。面板与轮廓按钮边界为 1 pt，分隔线也为 1 pt；侧栏分类通过整行点击区和选中底色组织，不绘制重复小框。

Logo 的逻辑槽位在管理侧栏为 32 pt、浮窗为 24 pt。当前 Logo PNG 为 112 × 124 像素；32 pt 槽位中的图像框为 112/3 × 124/3 pt，x = 0、y = −5.261 pt，其他槽位按宽度同比缩放。五个分类色点 PNG 均为 81 × 81 像素，显示为 27 × 27 pt，并相对 7 pt 槽位向左／上各外扩 10 pt。菜单栏使用独立单色模板图标，36 像素资源显示为 18 逻辑 pt，由系统着色；不把彩色 Logo 当菜单栏模板。八个打包 PNG 均保留 `impeccable:prompt` 来源元数据，Figma 导出的七张另保留 `Software`；应用图标和资源说明见 [Design 资源说明](macOS/PromptInjector/Resources/Design/README.md)。

应用图标 `AppIcon.png` 保留黑色圆角底块和原有彩色品牌，只用内置 imagegen 去除底块外的白色画布；精确编辑提示保存在 PNG 元数据中。当前透明源为 1254 × 1254 像素，运行时应用图标和 ICNS 共用这张源图，打包通过系统 `sips`／`iconutil` 生成 16–1024 像素规格。界面 Logo 与菜单栏模板维持各自资源，不随应用图标改动。

装饰边界、Logo 和柔光不拦截正文选择、按钮点击或边缘缩放。

## Components

### Buttons

复制、编辑、插入统一为透明底、细灰边、白色图标的 40 × 40 pt 按钮；浮窗只在详情显示复制和插入。管理新建为深灰填充、白色加号的 40 × 40 pt 纯图标按钮，保留“新建条目” tooltip 与可访问名称；保存仍使用带文字的主要操作。主要操作悬停／按下依次提亮；透明操作悬停使用 6% 白，按下使用 12% 白。主要／选中按钮常态为 `selection`，悬停为 #323232，按下为 #353535。禁用图标使用 `tertiary`。

图标来自本地 Figma SVG，未映射项才回退 SF Symbols。保留 tooltip、可访问名称和 `ActionButton` 的 AppKit exterior 焦点环。返回／关闭的点击区为 32 pt，不误套底部动作尺寸。

### Navigation

浮窗第一层只显示分类名、数量和箭头；第二层只显示标题、简述和箭头；第三层再加载正文。悬停使用 `band`，选中使用 `selection`。管理侧栏导航与分类保持完整行点击区，数量弱化；列表与详情分别滚动。

全局快捷键、Return、Shift + Return、Escape、详情 `⌘Return` 的约定继续见 [launcher-brief.md](docs/launcher-brief.md)。隐藏再显示保留页面、滚动和选择。移除目标标签不改变唤起时捕获目标、插入前重新确认及失败时保留复制的行为；插入只填写，不发送。

### Segmented Views

`ChoiceSegments` 使用 `band` 底色、4 pt 内边距、4 pt 按钮间隙；选中片使用更小圆角和 `selection`，文字为白色，未选为辅助灰。浮窗详情高 34 pt，编辑页高 44 pt，统计时段高 40 pt。分段使用原生按钮，选中状态提供辅助功能值。

### Panels and Documents

`SurfaceView` 默认是 `panel` 底、细灰边的安静容器；横向操作条使用 `band` 且不描边。管理预览与浮窗正文可选择，完整复制始终读取原始 Prompt；不从屏幕拼接被截断的文本。浮窗“经验与来源”保留独立字段与分隔线，不拆成四张重复卡片。

### Inputs and Editor

搜索框只搜索标题与简述，高 40 pt，使用低对比深色背景、灰边、搜索图标与占位提示。标题／分类／来源字段高 44 pt；长文本通过原生 `NSTextView` 编辑，支持撤销、白色插入光标与独立滚动。输入控件边界维持中性，编辑主面板使用较清楚的 `editor-outline`，不以分类色描边。

保存状态放在顶部操作条，必填和保存错误就近显示；常态不重复提示必填规则，也不附加作者或格式说明。失败保留输入、草稿与重试能力；视觉成功状态不能先于本地保存成功。管理表单的长内容不移入快捷浮窗。

### Feedback

常态界面保留内容、字段、数量、操作名称和快捷键；品牌副标题、重复筛选名称、本地保存／可调用说明、示例来源说明与静态页脚不占用页面空间。空状态、失败原因、保存／草稿状态、操作 tooltip 和快捷键提示继续保留；移除说明文字不删除原始经验、来源、解释或 Prompt 数据。

浮窗成功提示显示 2 秒，常规错误显示 8 秒；需要用户处理的插入错误持续显示并保留复制，缺权限时提供权限入口。目标、权限或写入校验失败以明确的错误类型锁住插入，按钮与 `⌘Return` 共用同一门禁；仅在重新唤起并捕获到有效新目标后解除，同时清除旧错误反馈。剪贴板写入失败或仍按住快捷键属于可重试错误，不锁住新一次尝试。错误可换行并扩展底部高度，避免遮挡动作；反馈同步发出辅助功能公告。统计记录失败与已完成的复制／插入区分呈现，不用失败统计撤销已完成动作的事实。

## Do's and Don'ts

### Do:

- **Do** 使用系统字体、原生红黄绿按钮与独立 Space 全屏、应用 Logo、文字选择和明确的可访问名称。
- **Do** 让通用控件保持中性白／深灰，按具体位置应用分类色。
- **Do** 让管理预览只显示对齐的分类名称，在侧栏、编辑器和统计中保留分类色点；浮窗只使用分类文字柔光。
- **Do** 复用本地资源：Logo／色点使用 3 倍 PNG 保留柔光和正确逻辑尺寸，SVG 保留为矢量来源。
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
