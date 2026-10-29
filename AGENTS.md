# Prompt Injector · Agent 工作约定

这是个人使用的原生 macOS 工具：收集他人分享的 Agent 经验，保留原文和来源，经 LLM 整理为可编辑的 Prompt，再快速插入正在使用的输入框。

## 开始工作

- 产品事实见 [PRODUCT.md](PRODUCT.md)，阶段范围与当前进度见 [docs/roadmap.md](docs/roadmap.md)。后续 Stage 的界面或预览不代表功能已实现。
- 改客户端结构或数据流前读 [docs/architecture.md](docs/architecture.md)；做界面前读 [DESIGN.md](DESIGN.md)、[docs/launcher-brief.md](docs/launcher-brief.md) 和 [docs/prototype.md](docs/prototype.md)。
- 已有 Swift/AppKit 浮窗与 SQLite 分层内容库；Stage 1 已在当前 macOS / Codex 普通主输入框范围验收完成，证据和边界见 [docs/stage1-acceptance.md](docs/stage1-acceptance.md)。构建和测试使用 [README](README.md) 中实际验证过的命令；不要将计划命令写成已可用。
- 继续开发前读 [docs/development.md](docs/development.md) 与 [docs/stage2-plan.md](docs/stage2-plan.md)：每个可用小版本单独提交，正文保留改动、验证、风险和回滚边界；代码回滚不等于数据回滚。
- 实现授权、原型审核状态只在 [docs/prototype.md](docs/prototype.md) 维护。按现有授权继续，不重复索要同一批准，也不把已否决稿重新作为视觉依据。

## 技术与范围

- 客户端用 Swift + AppKit，局部按需要结合 SwiftUI；正式本地数据使用 SQLite。打包 JSON 仅作为首次事务导入的种子，正常读取必须走 SQLite repository。保持原生 macOS 窗口、焦点、菜单和键盘行为。
- Stage 1–2 不引入云端依赖。Stage 3 才加入 Go + chi 的 LLM 整理服务；Stage 4 才加入 PostgreSQL 和同步。不提前实现账号、注册、多用户或 Windows 支持。
- 分类、条目列表、详情是同一浮窗的三个层级。长内容编辑放在独立管理窗口。
- 浏览、搜索、复制和插入已有内容均使用本地数据；这些路径不调用 LLM，也不等待网络。

## 不可破坏的行为

- 插入仅填写目标输入框，绝不自动发送、提交或模拟用于发送的回车。先验证 Codex；其他应用逐个验证后再声明支持。
- 唤起时记录目标应用和输入框；插入前重新确认目标有效。权限缺失、焦点丢失或目标失效时显示具体原因，保留复制操作，不向猜测的目标写入。
- 默认全局快捷键为 `⇧⌥Space`，可改为 `⌃⇧Space`；隐藏时显示、可见时隐藏，即使焦点在其他应用。切换保留页面、滚动与选择，注册新键失败保留原键。
- Return 只在前两层打开；Shift + Return 只在第二、三层返回；详情页 `⌘Return` 才插入。Escape 保持返回和顶层隐藏行为。
- 原始经验、作者/来源、解释和 Prompt 分开保存。LLM 输出是待审核候选，不静默覆盖原文或用户编辑。
- 录入原文先存本地草稿。生成失败、取消或重试不得丢失输入；新结果不得直接覆盖已修改内容。
- 数据有稳定 ID；导入、迁移和同步保持 ID。批量改动使用事务；同步检查版本并处理删除，冲突不得静默覆盖。
- 本地保存成功后通知列表刷新；云端刷新完成后再切换缓存。保持选择位置，明确显示失败，不用高频轮询代替更新设计。

## 验证与交付

- 每次代码/行为修改和每个 Stage 交付前运行 `python3 scripts/test-suite.py`，覆盖既有功能，案例与报告约定见 [docs/testing.md](docs/testing.md)。锁屏/无桌面时只可先跑 `--headless` 并标记部分验证，解锁后补完整套件；失败必须定位、修复后重跑。

- 排查 bug 前读 [docs/debugging.md](docs/debugging.md)，核对运行包与日志的构建 ID/源码指纹，再按 operationID 追踪。开发涉及行为变化时补齐相关 `DiagnosticLog` 事件，包括提前返回和异常；只用固定诊断字段，不记录正文或凭证。
- 已确认 bug 要保留能阻止同类回归的最小测试；能复现时先验证测试在修复前失败，再修复。检查相同条件、边界和相邻失败路径，只一并修有证据的问题，不扩大为无关重构。
- 修复后在 [docs/bugs.md](docs/bugs.md) 留下根因、修复范围与测试入口，在 [CHANGELOG.md](CHANGELOG.md) 记录改变。自动化不能覆盖的系统场景明确写出，不用模拟成功替代真实验收。

- Stage 1 完整实现要求：第一层只读分类，第二层只读标题和简述，第三层再加载正文。已实现后台按层查询，后续改动必须保留这项边界。记录实测浮窗延迟、空闲 CPU、内存和样本量，不捏造数字。
- 系统插入必须在真实 macOS 输入框验收，覆盖成功、未授权、目标失效及复制降级。Figma 连线、模拟目标或代码存在不算真实插入验收。
- 数据修改验证保存后重启、导入导出往返，以及失败时原文/编辑保留。只运行与改动相关的实际检查。
