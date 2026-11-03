# Prompt Injector

<!-- impeccable:product-schema 1 -->

## Platform

个人使用的原生 macOS 桌面应用。当前工程部署目标为 macOS 14，实际最低系统兼容性待验证。

## Stack

- 已实现：Swift + AppKit、Swift Package Manager；SQLite 本地库与首次导入用 JSON 种子；UserDefaults 保存窗口几何与快捷键选择。
- Stage 1 已有 SQLite 本地内容与后台分层读取；已完成当前环境下的离线、未授权、目标失效实测与初步性能基线。SwiftUI 仅在需要时使用，当前界面为 AppKit。
- Stage 3：Swift 客户端直接请求 DeepSeek API，Keychain 保存 API key，无中转服务器。
- Stage 4：PostgreSQL 正式内容，SQLite 保留离线缓存与草稿。

## Users

先服务作者本人，在使用 Codex、ChatGPT Web 等 Agent 工具时收集、整理和调用经验。当前不做账号、注册、多用户或 Windows 版。

## Product Purpose

把不同作者分享的 Agent 使用经验，内化成有来源、可理解、可修改、可重复使用的 Prompt，迅速放回正在工作的输入框。用户始终决定何时发送。

## Operating Context

调用：原输入框 → 全局快捷键 → 分类 → 标题与简述列表 → 完整详情 → 复制或插入。

已接入开发版的手动维护：独立管理窗口 → 手动填写各字段／本地草稿 → 保存 → 浮窗显示更新。管理页支持标题与简述搜索、真实使用次数统计；原生新版验收状态见 [移植记录](docs/figma-integration.md)。

已接入开发版的经验整理：加号 → 粘贴原文或链接 → 本地会话草稿 → 读取链接并识别单条／多条经验 → 按条讨论与独立勾选 → 整理已勾选 → 逐条审核修改 → 批量事务保存。每条经验按稳定 ID 保留讨论、未发送输入与候选；来源和作者原句独立保留。已有手动编辑草稿继续在原编辑器恢复。链接读取依赖网络；失败时保留输入，可改用粘贴正文。

已有条目可在预览操作区删除，先确认具体标题；删除正式条目保留历史使用事件和已有会话归档，不提供回收站。实现与数据回滚边界见 [经验整理实现记录](docs/experience-dialogue.md)。

初始分类：需求对接、编码、排查、审查、发布，保留原 ID；分类来自 SQLite，可在编辑器新增和选择。

## Capabilities and Constraints

- Stage 1 已在当前 macOS / Codex 普通主输入框范围完成调用闭环与验收。阶段状态见 [roadmap](docs/roadmap.md)。
- 同一浮窗逐层切换，支持鼠标、方向键、Return、Shift + Return 与 Escape。隐藏后再次显示保留当前页面、选择和滚动。
- 默认全局快捷键为 `⇧⌥Space`，菜单可改为 `⌃⇧Space`；可见时再次按下会隐藏，即使已切到其他应用。
- 浮窗详情保留原始经验、来源、解释、Prompt 四个独立字段，正文只读可选；长内容在独立管理窗口编辑。
- 已有内容的调用路径本地运行，不请求网络。首次事务导入七条 JSON 示例；之后分类、摘要、正文按层查 SQLite。
- Codex 是自动插入的首个验收目标，快捷唤起、选择、完整插入且不发送的核心流程已在 2026-10-29 由用户实测确认；断网、未授权/复制降级和原目标失效已在 2026-10-30 前完成实测。ChatGPT Web 仍是后续兼容目标。
- 经验整理由客户端直连 DeepSeek，链接内容通过 DeepSeek Fetch 读取；原文片段必须能在读取内容中逐字定位，模型识别与整理不是来源事实。审核前均为本地会话草稿，取消、失败和重试保留输入；生成结果不会静默覆盖已修改候选。
- 本地单条／批量保存仅在 COMMIT 后刷新；分类按实时数据库上下文选择或同事务新增，同名去重。正式内容在 `library.sqlite3`，会话草稿、归档及使用历史在 `library-activity.sqlite3`，完整恢复须保留两库。
- 云端引入后支持启动、保存后和手动刷新，不承诺推送或跨端毫秒级更新。
- 性能和资源消耗以实测为准；已有带样本数的热唤起与空闲 CPU/RSS 基线，见 [验收报告](docs/stage1-acceptance.md)，不声称达到未约定的资源预算。

## Brand Commitments

工作名称：Prompt Injector。使用原生 macOS 行为与系统字体；最新界面采用 Figma 导出的 Logo、模板图标和控件资源。深色中性面板、白色通用控件与十五色分类循环用于管理窗口和浮窗，前五色和顺序保留；来源和 Prompt 保持可读。来源标识覆盖 X、GitHub、Reddit。视觉依据和原型沿革见 [prototype](docs/prototype.md)，具体规范见 [DESIGN.md](DESIGN.md)。

## Evidence on Hand

- 需求来源：作者关于个人经验收集、提示词整理和快捷调用的项目说明。
- 原生源码位于 [macOS/PromptInjector](macOS/PromptInjector/)，当前七条内容均标为「项目内置示例」，没有虚构外部作者来源。
- 已有构建、单元测试、原生窗口截图，以及隔离库中的真实链接读取／识别／讨论／整理／保存重开验证；具体报告和系统验收边界见 [testing](docs/testing.md)。原生两条经验 fixture 截图与 Figma 二十条演示分别记录，设计审核和实现授权见 [prototype](docs/prototype.md)。

## 当前录入流程 · v0.5

取消多轮聊天。原文／链接一键整理，原文与 Prompt 分区；Prompt 可以手贴或明确生成。多条独立选择、逐条审核后批量保存；手动填写不依赖 LLM。旧会话草稿保留，新增经验以原文边界约束避免过度拆分。

## Product Principles

1. 经验可追溯，生成结果由用户审核并可编辑。
2. 高频调用留在本地，系统交互可靠优先。
3. 保存后及时更新，失败明确可恢复。
4. 按阶段引入复杂度，保持轻量。

## Open Decisions

首个模型服务已选 DeepSeek，不部署中转；模型为 V4.1 Flash 1017（官方别名 deepseek-flash），启用 high 思考。更新延迟与内存预算待确定；macOS 14、其他应用兼容性及大样本/长期性能待验证。question 框兼容性按用户决定延期。
