# Prompt Injector · Agent 工作约定

这是个人使用的原生 macOS 工具：收集他人分享的 Agent 经验，保留原文和来源，经 LLM 整理为可编辑的 Prompt，再快速插入正在使用的输入框。

## 开始工作

- 产品与阶段范围见 [PRODUCT.md](PRODUCT.md) 和 [路线图](docs/roadmap.md)。确认功能是否已实现时，以当前分支的代码和验收记录为准。
- 改客户端结构或数据流前读 [docs/architecture.md](docs/architecture.md)。新增或改界面时，先按 [模块与组件选用](DESIGN.md#模块与组件选用) 找最接近的现有页面，复用它的容器、组件和对齐线，核对常用与最小窗口。改浮窗再读 [launcher-brief.md](docs/launcher-brief.md)，需要查设计决策时读 [prototype.md](docs/prototype.md)。
- 开发与回滚见 [docs/development.md](docs/development.md)。继续 Stage 2 前读 [docs/stage2-plan.md](docs/stage2-plan.md)。每个可用小版本单独提交，正文保留改动、验证、风险和回滚边界。
- 写代码前向用户说明改动位置、影响的功能和预期效果，说明后再动手。
- 需要新增功能、配置项、开关或界面文案时，先说明使用场景并征得用户同意。将确认的产品规范更新到对应的产品或设计文档，供后续改动沿用。
- 实现授权、原型审核状态只在 [docs/prototype.md](docs/prototype.md) 维护。按现有授权继续，不重复索要同一批准，也不把已否决稿重新作为视觉依据。

## 技术与范围

- 客户端用 Swift + AppKit，局部按需要结合 SwiftUI；正式本地数据使用 SQLite。打包 JSON 仅作为首次事务导入的种子，正常读取必须走 SQLite repository。保持原生 macOS 窗口、焦点、菜单和键盘行为。
- 正式内容保存在 schema v1 的 `library.sqlite3`；草稿和使用事件在伴随库 `library-activity.sqlite3`。恢复完整用户状态须同时保留两库，代码回滚不恢复已编辑内容，不删除伴随库来模拟回滚。
- Stage 1–2 的本地调用路径不引入云端依赖。Stage 3 由 Swift 客户端直连 DeepSeek，API key 仅存本机 Keychain，不自建 Go + chi 中转；Stage 4 的 PostgreSQL 和同步仍属后续计划。不提前实现账号、注册、多用户或 Windows 支持。
- 分类以 SQLite 实际数据为准，初始五类 ID 保持不变。新增分类与条目同事务保存并做同名去重。浮窗按分类、标题与简述、正文三层后台查询。长内容编辑放在独立管理窗口。
- 浏览、搜索、复制和插入已有内容均使用本地数据；这些路径不调用 LLM，也不等待网络。

## 不可破坏的行为

- 插入仅填写目标输入框，绝不自动发送、提交或模拟用于发送的回车。先验证 Codex；其他应用逐个验证后再声明支持。
- 唤起时记录目标应用和输入框；插入前重新确认目标有效。权限缺失、焦点丢失或目标失效时显示具体原因，保留复制操作，不向猜测的目标写入。
- Codex 空主框的占位归一化复用 `TargetText` 与 `InjectionService.readContents`：捕获、预检、回读共用规则，仅检查已捕获目标内的结构标记，最多 32 节点。不按提示文案或长度猜空，不放宽全文匹配；question 框兼容性继续延期。
- 默认全局快捷键为 `⇧⌥Space`，可改为 `⌃⇧Space`；隐藏时显示、可见时隐藏，即使焦点在其他应用。切换保留页面、滚动与选择，注册新键失败保留原键。
- Return 只在前两层打开；Shift + Return 只在第二、三层返回；详情页 `⌘Return` 才插入。Escape 保持返回和顶层隐藏行为。
- 管理窗口留在自己的 macOS 桌面空间。已有窗口可见时，Dock 重开由系统处理。关闭管理窗口先保存草稿，全屏时等系统完成退出再隐藏。
- 原始经验、作者/来源、解释和 Prompt 分开保存。LLM 输出是待审核候选，不静默覆盖原文或用户编辑。
- 录入原文先存本地草稿。生成失败、取消或重试保留输入，晚到的结果不能覆盖手改或恢复已移除的条目。工作台追加多篇时保留各自的原文与来源，部分保存保留剩余条目和待录入草稿。
- 数据有稳定 ID；导入、迁移和同步保持 ID。批量改动使用事务；同步检查版本并处理删除，冲突不得静默覆盖。
- 创建／编辑复用 `PromptLibrary` 后台队列和 repository 事务，仅在 COMMIT 成功后通知；分类移动刷新新旧分类，按稳定 ID 保留选择，迟到结果不得恢复可插入的旧详情。编辑检查原快照，失败保留输入和 ID；退出前完成草稿保存与队列排空。
- 使用统计只记录明确成功的完整 Prompt 复制和全文验证成功的插入，内部粘贴不额外计为复制。云端刷新规则只在后续同步阶段实施。

## 验证与交付

- 迭代时按改动选验证。文案核对实际显示，逻辑用 `swift test --filter` 并确认命中目标用例，跨模块跑 `python3 scripts/test-suite.py --tier fast`。界面、焦点和按键用 `--tier desktop`，采集截图用 `--tier visual`。
- 合并前跑 `--tier merge`，GitHub PR 使用同一层。代码、行为或 Stage 交付前跑无参数完整套件。锁屏或无桌面时先跑 `--headless`（合并层），标记部分验证，解锁后补完整套件。案例与报告见 [docs/testing.md](docs/testing.md)。
- 多 worktree 同步前检查工作区、远端和提交祖先关系，已合并的分支不重复合并。合并回滚先核对父提交。测试套件默认构建隔离 App，手动打审查包时用 `PROMPT_INJECTOR_APP_OUTPUT` 指向独立目录。原生验收用 `--verify-ui` 隔离数据库，普通启动仍访问正式库。
- 修 bug 先定位根因。按 [docs/debugging.md](docs/debugging.md) 核对运行包的构建 ID 和源码指纹，有 operationID 时沿它追踪。连续两次修复未奏效时，先补相关日志并重现，依据实际状态再修改。行为变化补齐 `DiagnosticLog` 的相关阶段和失败分支，只用固定诊断字段，不记录正文或凭证。
- 已确认 bug 在现有测试套件补最小回归。能复现时先跑出失败，修复后重跑并复查实际效果，报告结果和未验证场景。检查相邻失败路径，只一并修复有证据的问题。
- 改管理窗口的桌面空间、激活或关闭逻辑时，在解锁的 Mac 上跑 `python3 scripts/test-suite.py --tier desktop`。验证范围见 [窗口验收记录](docs/testing.md#2026-11-18--管理窗口与全屏关闭)。
- 修复后在 [docs/bugs.md](docs/bugs.md) 留下根因、范围和测试入口，在 [CHANGELOG.md](CHANGELOG.md) 记录改变。按影响范围分别记录本次自动化、真实 API 和人工验收，历史结果注明版本。性能报告记录浮窗延迟、空闲 CPU、内存和样本量。
- 改系统插入时，在真实 macOS 输入框验证成功、未授权、目标失效及复制降级。历史人工验收见 [Stage 1](docs/stage1-acceptance.md) 和 [Stage 2](docs/stage2-acceptance.md)。
- 数据修改验证保存后重启、导入导出往返，以及失败时原文/编辑保留。只运行与改动相关的实际检查。
