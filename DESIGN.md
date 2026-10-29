---
name: Prompt Injector
description: 原生深色工具浮窗，清楚呈现经验、来源与 Prompt。
colors:
  text: "rgb(94% 94% 94%)"
  secondary: "rgb(66% 66% 66%)"
  tertiary: "rgb(58% 58% 58%)"
  focus: "rgb(76% 76% 76%)"
  error: "rgb(100% 68% 62%)"
  surface-tint: "rgb(11.3% 10.9% 10.8% / 78%)"
  surface-solid: "rgb(11.3% 10.9% 10.8%)"
  outline: "rgb(100% 100% 100% / 22%)"
  outline-contrast: "rgb(100% 100% 100% / 45%)"
  detail-fill: "rgb(100% 100% 100% / 2.8%)"
  rule: "rgb(100% 100% 100% / 9%)"
  row-hover: "rgb(100% 100% 100% / 4.5%)"
  selection: "rgb(100% 100% 100% / 9%)"
  action-fill: "rgb(89% 89% 89%)"
  action-ink: "rgb(12% 12% 12%)"
typography:
  title:
    fontFamily: system-ui
    fontSize: 20px
    fontWeight: 600
  row:
    fontFamily: system-ui
    fontSize: 14px
    fontWeight: 500
  body:
    fontFamily: system-ui
    fontSize: 14px
    fontWeight: 400
  secondary:
    fontFamily: system-ui
    fontSize: 12px
    fontWeight: 400
  label:
    fontFamily: system-ui
    fontSize: 12px
    fontWeight: 500
  code:
    fontFamily: ui-monospace
    fontSize: 13px
    fontWeight: 400
rounded:
  shell: 26px
  document: 10px
  button: 8px
  row: 7px
spacing:
  small: 8px
  section: 16px
  title-gap: 20px
  content-edge: 24px
components:
  insert-button:
    backgroundColor: "{colors.action-fill}"
    textColor: "{colors.action-ink}"
    rounded: "{rounded.button}"
    size: 34px
  copy-button:
    backgroundColor: transparent
    textColor: "{colors.text}"
    rounded: "{rounded.button}"
    size: 34px
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
  detail-document:
    backgroundColor: "{colors.detail-fill}"
    textColor: "{colors.text}"
    rounded: "{rounded.document}"
    padding: "{spacing.section}"
---

# Design System: Prompt Injector

## Overview

**Creative North Star: "原生深色工具浮窗"**

中性偏暖的炭灰外壳承载紧凑、可读的工具界面。材质吸收背景色，文字保持清晰；系统字体、SF Symbols 和原生文本选择服务于快速查找与调用。

本规范从当前 AppKit 源码提取。外壳参考和已否决方案见 [原型记录](docs/prototype.md)，页面布局见 [浮窗约定](docs/launcher-brief.md)。前置 token 的 CSS 单位用于跨工具预览；在 AppKit 中对应同数值的逻辑 pt，颜色按源码分量表达。系统材质会随桌面背景变化，不能由单一色值完整复刻。

**Key Characteristics:**

- 中性暖灰系统材质与连续圆角。
- 比例字体正文，清晰的标题和简述层级。
- 单容器详情，以细线分段。
- 图标操作，原生焦点、选择与键盘行为。

## Colors

色彩围绕中性偏暖的炭灰和白色层次组织，键盘焦点使用中性白。

### Primary

- `focus`：列表拥有键盘焦点时使用中性白描边，绘制透明度为 65%。
- `action-fill` / `action-ink`：插入按钮的明亮底色和深色图标。
- `error`：失败反馈，不作为常规装饰色。

### Neutral

- `text`、`secondary`、`tertiary`：正文、辅助说明、弱提示和箭头。
- `surface-tint`：以中性偏暖的遮罩覆盖系统 HUD 材质；降低透明度时使用同色不透明的 `surface-solid`。
- `outline`：窗口细边界；提高对比度时使用 `outline-contrast`。
- `detail-fill` / `rule`：单个详情容器与段间细线。
- `row-hover` / `selection`：轻微悬停与选中层次。

## Typography

使用 `NSFont.systemFont`；只有 Prompt 中的围栏代码使用 `NSFont.monospacedSystemFont`。中文、英文说明和 Prompt 普通段落不整体等宽。

层级为详情标题、列表标题与正文、简述和字段标签。页头为系统中等字重，来源文本较正文略小并使用辅助色。正文按字符换行；普通段落额外行间距 5 pt，代码为 3 pt。标题随窗口宽度换行，不通过缩字号适应小窗。

## Layout

单窗三级导航，固定页头与底部动作，中间独立滚动。窗口初始 620 × 520 pt，最小 360 × 300 pt。主要内容共用 24 pt 左右边缘，分类行通过图标槽缩进名称；详情容器内统一使用 section 间距。

页头不重复显示右上应用名。详情标题、单容器外边缘和底部分隔线左对齐。布局具体数值和键盘行为集中维护在 [launcher-brief.md](docs/launcher-brief.md)。

## Elevation & Depth

窗口使用 `NSVisualEffectView` 的 HUD 材质、behind-window 混合、中性暖灰遮罩和系统窗口阴影。内部依靠透明白色填充和细线区分层次，不堆叠带阴影卡片。降低透明度时隐藏材质并使用不透明底色，提高对比度时增强外边线。

色彩与质感以用户最新 Companion 对照图校准；匹配深色测试背景下的主导中性色差为每通道 1、1、0，取样依据见 [原型记录](docs/prototype.md)。此结果只说明该背景与截图条件下接近，不能推断 Companion 的内部材质参数或所有背景上的精确一致。

## Shapes

窗口采用连续圆角；详情容器、按钮和列表行采用更小圆角，避免内部重复外壳的膨胀轮廓。窗口和详情容器为细边框，三个详情分隔线与内容同缩进。装饰边界不拦截点击、文字选择或边缘缩放。

## Components

### Buttons

复制与插入是图标按钮，保留 tooltip 和可访问名称。插入为明亮填充，复制默认为透明；悬停和按下提升填充，禁用时弱化图标。返回与关闭沿用透明图标样式，缺权限时出现文字按钮「开启权限」。原生焦点环保留。

### Navigation

分类行显示 SF Symbol、名称和右箭头；条目行显示标题、简述和右箭头。选中与悬停可区分，只有实际键盘焦点出现中性白描边。前进时新内容从右侧 16 pt 内轻移并淡入，返回时方向相反，分别持续 0.18 / 0.16 秒；旧内容向反方向移出 10 pt 并在 0.12 秒内淡出。只对滚动内容区域做过渡，材质、页头和底部保持静止。减少动态效果时立即切换。旧页透明快照不接收点击或辅助功能焦点，快速连续导航、缩放和隐藏都会清理旧动画与快照，不重置选择和滚动。

浮窗出现时从 97.5% 轻微舒展至完整尺寸，配合 0.18 秒淡入；收起时回收到 98.5%，配合 0.12 秒淡出。没有反复弹跳、波纹或装饰性闪光。动效只影响临时呈现，不改窗口几何或保存尺寸；连续开关会中断并反向，旧关闭回调不会隐藏重新打开的窗口。稳定显示时窗口 alpha 为 1，不通过整体透明度模拟磨砂。减少动态效果时立即切换；插入交接焦点时也立即隐藏。

### Detail Document

标题下仅有一个轻边框容器，原始经验、来源、解释和 Prompt 以标签与细线区隔。各段文本可选择，空字段隐藏。复制按钮读取完整原始 Prompt，不丢失围栏或换行。

### Feedback

反馈位于底部。普通成功提示显示 2 秒，常规错误显示 8 秒；需用户处理的插入错误持续显示，保留复制和权限入口。错误可换行，底部扩展高度，不遮住动作。反馈同时发送辅助功能公告。

## Do's and Don'ts

### Do:

- **Do** 保持主要内容左边缘一致，容器内部使用统一缩进。
- **Do** 保留简述、来源和完整 Prompt 的可读性。
- **Do** 为图标操作提供提示与可访问名称。
- **Do** 尊重降低透明度、提高对比度和减少动态效果设置。

### Don't:

- **Don't** 重新采用已否决的浅色 Figma 稿。
- **Don't** 把详情拆成四张重复卡片或把普通正文全部等宽。
- **Don't** 在右上重复应用名，或用固定高度裁切长正文。
- **Don't** 用界面成功状态代替真实输入框写入确认。
