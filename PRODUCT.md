# Prompt Injector

<!-- impeccable:product-schema 1 -->

## Platform

个人使用的原生 macOS 桌面应用。当前工程部署目标为 macOS 14，实际最低系统兼容性待验证。

## Stack

- 已实现：Swift + AppKit、Swift Package Manager；SQLite 本地库与首次导入用 JSON 种子；UserDefaults 保存窗口几何与快捷键选择。
- Stage 1 已有 SQLite 本地内容与后台分层读取；已完成当前环境下的离线、未授权、目标失效实测与初步性能基线。SwiftUI 仅在需要时使用，当前界面为 AppKit。
- Stage 3：Go + chi 连接一个待选模型服务，提供经验整理。
- Stage 4：PostgreSQL 正式内容，SQLite 保留离线缓存与草稿。

## Users

先服务作者本人，在使用 Codex、ChatGPT Web 等 Agent 工具时收集、整理和调用经验。当前不做账号、注册、多用户或 Windows 版。

## Product Purpose

把不同作者分享的 Agent 使用经验，内化成有来源、可理解、可修改、可重复使用的 Prompt，迅速放回正在工作的输入框。用户始终决定何时发送。

## Operating Context

调用：原输入框 → 全局快捷键 → 分类 → 标题与简述列表 → 完整详情 → 复制或插入。

计划中的采集：独立管理窗口粘贴经验 → 本地草稿 → LLM 整理分类、标题、简述、解释和 Prompt → 人工检查修改 → 保存 → 客户端显示更新。

固定分类：需求对接、编码、排查、审查、发布。

## Capabilities and Constraints

- Stage 1 已在当前 macOS / Codex 普通主输入框范围完成调用闭环与验收。阶段状态见 [roadmap](docs/roadmap.md)。
- 同一浮窗逐层切换，支持鼠标、方向键、Return、Shift + Return 与 Escape。隐藏后再次显示保留当前页面、选择和滚动。
- 默认全局快捷键为 `⇧⌥Space`，菜单可改为 `⌃⇧Space`；可见时再次按下会隐藏，即使已切到其他应用。
- 详情区保留原始经验、来源、解释、Prompt 四个独立字段。当前内容只读；真实复制已检查。
- 已有内容的调用路径本地运行，不请求网络。首次事务导入七条 JSON 示例；之后分类、摘要、正文按层查 SQLite。
- Codex 是自动插入的首个验收目标，快捷唤起、选择、完整插入且不发送的核心流程已在 2026-10-29 由用户实测确认；断网、未授权/复制降级和原目标失效已在 2026-10-30 前完成实测。ChatGPT Web 仍是后续兼容目标。
- 后续本地保存须及时刷新；云端引入后支持启动、保存后和手动刷新，不承诺推送或跨端毫秒级更新。
- 性能和资源消耗以实测为准；已有带样本数的热唤起与空闲 CPU/RSS 基线，见 [验收报告](docs/stage1-acceptance.md)，不声称达到未约定的资源预算。

## Brand Commitments

工作名称：Prompt Injector。使用原生 macOS 行为、系统字体与 SF Symbols。当前视觉为深色炭灰材质浮窗，内部紧凑、清晰；来源和 Prompt 保持可读。视觉依据和原型沿革见 [prototype](docs/prototype.md)，具体规范见 [DESIGN.md](DESIGN.md)。

## Evidence on Hand

- 需求来源：作者关于个人经验收集、提示词整理和快捷调用的项目说明。
- 原生源码位于 [macOS/PromptInjector](macOS/PromptInjector/)，当前七条内容均标为「项目内置示例」，没有虚构外部作者来源。
- 已有构建、单元测试和原生窗口截图；详细验证边界见 [prototype](docs/prototype.md)。

## Product Principles

1. 经验可追溯，生成结果由用户审核并可编辑。
2. 高频调用留在本地，系统交互可靠优先。
3. 保存后及时更新，失败明确可恢复。
4. 按阶段引入复杂度，保持轻量。

## Open Decisions

首个模型服务、部署地点、更新延迟与内存预算待确定；macOS 14、其他应用兼容性及大样本/长期性能待验证。question 框兼容性按用户决定延期。
