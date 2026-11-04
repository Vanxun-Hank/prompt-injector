# 开发、提交与回滚

## 从当前基线继续

2026-10-31 整合：Figma 原生分支与 main 的 `9a7fd0c` 共同作为当前实现。合并包完整套件 73 Swift、7 Python、111 原生检查和 19 张截图通过，报告见 testing.md。合并提交第一父为 UI 分支 `cf0dec3`，第二父为原 main `9a7fd0c`；如需回到合并前的 main，在独立回滚分支对该合并使用 `git revert -m 2 <merge-commit>`，运行完整回归后按授权推送。不要将普通提交的回滚命令机械套在合并提交上；数据仍须独立备份与恢复。

v0.2.0 的开发起点提交为 `feat: complete Stage 2 manual creation v0.2.0`，基于 `v0.1.0` / `a8b45c5448ac2eb9ccb7be577bbc24c23fa07f72`。本提交包括完整实现、最小回归、验收摘要及回滚边界；可用 `git log --all --oneline --grep='^feat: complete Stage 2 manual creation v0.2.0$'` 定位实际 SHA。该历史版本只支持手动新增；当前整合 Figma 分支后另有编辑、管理页搜索、持久草稿与真实使用统计，整个 Stage 2 仍未完成。

历史完整套件 56 Swift、7 Python、82 原生检查通过；真实新增条目插入及重启持久化已完成当前环境复核，见 [stage2-acceptance.md](stage2-acceptance.md)。提交前在独立 `build/Commit-Review/Prompt Injector.app` 重跑完整套件，再次全部通过，源码指纹与用户复核包一致。所有自动化数据库均为临时库；普通启动审查包仍会使用正式资料库，只有 `--verify-ui` 使用隔离库。

历史用户人工复核包为 `build/Review-Empty-Fix/Prompt Injector.app`，构建 `20261030T092234Z`。实际运行包不因 Git 提交或合并自动升级；诊断时仍须核对构建 ID 与源码指纹，不能只看 HEAD。构建产物和原始日志不进入 Git。

`v0.1.0` 是首次公开的 Stage 1 基线。本项目在此之前没有 Git 历史；CHANGELOG 中的早期记录是开发事实，不代表存在对应旧提交。首次提交不能回到一个不存在的“上一版”，后续小版本可以明确回到这个基线。

后续 Agent 按顺序阅读：

1. `AGENTS.md`：范围与不可破坏的行为。
2. `PRODUCT.md`、`docs/roadmap.md`：已有能力和后续阶段。
3. `docs/stage2-plan.md`：下一项最小闭环、测试和回滚边界。
4. `docs/architecture.md`、`docs/bugs.md`：代码边界与已有回归。
5. `git log --oneline --decorate`、`git show <commit>`、`CHANGELOG.md`：实际变化。

不要把计划当作已实现，不为修复兼容性而移除“只写原目标、不发送、全文回读”的约束。question 框兼容问题已明确延期，不重新阻挡 Stage 2。

## v0.2.0 交接入口

| 职责 | 代码与约束 | 回归入口 |
| --- | --- | --- |
| 新增窗口 | `App/AppDelegate.swift` 菜单入口；`Features/ManagementWindow.swift` 与 `PromptEditor.swift` 承载内容、编辑和统计。保存失败保留输入与 UUID；草稿持久化，新增须明确点击加号 | `CreationTests`、`ManagementTests`、`ManagementVerification` |
| 后台持久化 | `Domain/Library.swift` 串行队列和成功通知；`Services/SQLitePromptRepository.swift` 参数绑定、BEGIN IMMEDIATE、排序分配、提交失败回滚。schema 仍为 v1，不用替换写入 | `SQLiteRepositoryTests`、`LibraryLoadingTests` |
| 浮窗更新 | `Features/LauncherView.swift` 仅刷新受影响分类，按稳定 ID 保留选择，代次门禁丢弃迟到结果，加载期间清空可插入对象 | `LibraryLoadingTests` 的刷新、迟到和失败案例 |
| 插入修复 | `Services/InjectionService.swift`、`Domain/TargetText.swift`、`TargetCapabilities.swift`。PI-015 保存捕获失败原因；PI-016 只凭已验证的 Codex 空文档结构归一化占位值，捕获/预检/回读共用规则 | `BugRegressionTests`、`TargetTextTests`、`PasteCapabilityTests`、`InsertionTests` |

路径均相对 `macOS/PromptInjector/`，测试在 `macOS/PromptInjectorTests/`。PI-015、PI-016 的根因和先失败后通过证据见 [bugs.md](bugs.md)。保持权限、原目标/选区复核、严格全文回读和剪贴板所有权检查；结构标记失效时重新采证，不按文案/长度猜测，也不增加盲目重试。

编辑、管理页搜索及使用统计已按用户后续授权实现。浮窗搜索、导入导出、删除、同步、CI 仍未实现；LLM 与分类扩展的本轮实现和验收见 [llm.md](llm.md)；后续闭环见 [stage2-plan.md](stage2-plan.md)，本次合并不自动开始下一项。当前人工跨应用终验仅覆盖短 Prompt；复杂长文本、其他应用和最低系统版本仍需实际验收。

## 每次提交保留什么

一次提交只围绕一个可说明、可验证的结果；大版本可由多个小提交组成。完成一个可用小版本再打版本标签，不对尚未实现的计划预打标签。

提交标题简洁，正文记录：

```text
feat: add manual prompt creation

Problem: 用户无法添加自己的条目。
Change: 管理窗口创建条目，事务成功后刷新浮窗。
Decisions: 保持 schema v1、稳定 ID、离线调用与原插入流程。
Validation: 完整套件结果，以及新增/重启/插入的实际验收。
Risks: 尚未覆盖的应用或系统场景。
Rollback: revert 本提交；新增条目保留，旧版仍可读取 schema v1。
Next: 编辑已有条目，见 docs/stage2-plan.md。
```

这是后续提交的模板；本次 v0.2.0 的实际记录以本提交正文和验收文档为准。正文写真实测试结果，失败或未测的部分明确标注。根因和测试入口写入 `docs/bugs.md`，发布行为写入 CHANGELOG。

本次源码提交与 main 合并/推送的授权记录见 [prototype.md](prototype.md#验收状态)。后续分支、push、标签和发布仍按当次任务授权执行，不能把本次授权当成永久授权。

## 回滚代码

共享的 main 优先用新增 revert 提交保留历史，不 force-push，不对用户未提交工作执行 reset --hard。

```sh
# 从仓库根目录开始；先确认 main 状态，不改动现有开发工作树
git log --all --oneline --grep='^feat: complete Stage 2 manual creation v0.2.0$'
git worktree add -b vanxun/revert-v0.2.0 ../prompt-injector-revert-v0.2.0 main
cd ../prompt-injector-revert-v0.2.0
# 将下列占位值替换为上面查到的实际 SHA
git show <v0.2.0-commit>
git revert <v0.2.0-commit>
env PROMPT_INJECTOR_APP_OUTPUT="$PWD/build/Rollback-Review/Prompt Injector.app" python3 scripts/test-suite.py
```

历史 `9a7fd0c` 通过快进方式纳入 main，撤销该普通提交使用 `git revert`，不需要 merge parent 参数。撤销后回到只读入口并恢复旧版 PI-015 提示、PI-016 空主框读数问题，当前客户端的空主框不据此保证可插入；已保存条目仍可读取。若后续提交依赖本次 API，先评估冲突及依赖，不能机械撤销其中一半。确认回归和实际使用可接受后，再按当次授权合并回滚分支并推送，不直接重写远端历史。

只想取出 Stage 1 稳定代码时，在独立目录检出标签：

```sh
git worktree add --detach ../prompt-injector-v0.1.0 v0.1.0
cd ../prompt-injector-v0.1.0
bash scripts/build-app.sh
```

构建默认会更新同一个本地 `.app` 输出位置。先退出正在运行的应用，完成数据备份后再启动旧版；使用同一个有效签名身份可减少辅助功能授权失效。不要同时运行新旧两个正式实例。

## 回滚不等于恢复数据

**Git 只管理源码，不能撤销用户已经保存、导入或删除的条目。** 数据库和日志不在仓库内。

- 更改 schema、执行批量导入或验证删除前，备份资料库。
- 在应用退出后，复制 `~/Library/Application Support/Prompt Injector/` 到独立备份目录；若必须在线备份，用 SQLite backup API，不能只拷贝可能正在写入的主文件。
- 恢复备份前再次保存当前数据，防止丢失回滚点之后的有效内容。
- 当前版本发现较新的 schema 会拒绝打开；不要直接改 `user_version`、删除库或重新导入示例来绕过版本门禁。
- Stage 2 优先保留 schema v1。必须迁移时，把迁移、备份/恢复说明、旧版兼容边界和测试作为单独可审查的改动。

## 发布前检查

运行 `python3 scripts/test-suite.py`。没有解锁桌面时可以先跑 `--headless`，但它不是完整验收。构建报告中的源码指纹用于核对实际二进制；`revision` 是构建时 HEAD，不能证明工作区没有未提交改动。

公开提交只包括源码、测试、文档和已检查的示例截图；不提交个人 SQLite、诊断日志、会话标识、证书、私钥、`.env`、构建包或原始截图。`artifacts/` 留在本地作为原始证据，公开文档提供去标识后的摘要。


## 常用安装包交付检查 · 2026-11-02

当前入口已于 2026-11-04 改为 `/Applications/Prompt Injector.app`，可在 Finder 的「应用程序」中打开。原 `~/Library/Application Support/Prompt Injector/Build/Prompt Injector.app` 是指向该包的符号链接，避免两个常用副本各自变旧。下文开发目录安装记录保留作历史；后续交付核对 `/Applications` 的实际进程与构建身份。完整安装、数据验证和恢复步骤见 [Applications 安装记录](applications-installation.md)。

独立审查包通过和打开，不代表常用安装位置已更新。此次用户重开后运行的仍是 `~/Library/Application Support/Prompt Injector/Build/Prompt Injector.app` 的 v0.2.0（20261030T162750Z），而 v0.3.1 只在 Reading-V2-Review。

完成已授权的本机更新时：正常退出旧进程并等待队列排空；成对备份两库和旧包；把通过回归的同一签名包暂存并验证，再替换常用路径。从该路径重新打开后，同时核对实际 PID 路径、app.started 的版本／build ID／源码指纹、签名及原生窗口。仅 `build/Prompt Injector.app` 链接或“已打开审查包”不算常用安装交付。

本次直接复制已验证 v0.3.1，没有重新编译。安装文件逐文件摘要与审查包一致；常用路径实际启动 build 20261101T044439Z。正式主库条目／分类与伴随库草稿／使用事件均与更新前备份逐表一致。证据：artifacts/installation/20261102T130352/report.json 和 installed-app.png。旧包／两库备份：`~/Library/Application Support/Prompt Injector/Backups/before-installed-v031-20261102T130352/`。仅恢复应用包不恢复数据；v0.2.0 仍有固定分类假设，不建议用它继续操作新增分类。

## v0.4 本机更新验收 · 2026-11-03

完整隔离套件与真实API通过后，正常退出v0.3.1，备份旧包和两库，再将同一签名包从 Experience-Review 复制到常用启动位置。实际PID62919运行 v0.4.0 / build20261102T162441Z / fingerprint d304150aced6f34ef18b938bcafcd57b7e74a97931ecc6cbb9554ab1f36d0da9，权限trusted=true，快捷键注册成功；实际加号进入新版双栏。已有categories/prompts/editor_drafts/usage_events逐字段不变，保留28条、7分类、5事件与0旧草稿。备份目录及逐文件校验记录见 artifacts/installation/v040/backup.json、report.json；不以此代替真实跨应用插入／物理断网验收。

## v0.5 本机更新 · 2026-11-04

V6 最终回归包原样安装，build20261103T163837Z／source d94a2d15362f0e4767628abbd9e57aeeebdde63d5ffab28f67ac5a084cf84ca4。备份 before-v050-20261103T163945Z 包含旧签名 App 和两库，Keychain 不变。正式库此时已是 0 条内容、7 分类；打开后内容和历史一致，已有经验草稿恢复并受用户并行操作，不能把草稿摘要变化算成安装数据丢失或声称逐字段不变。最新报告与恢复限制见 testing.md；不要恢复早期28条备份来覆盖后续有效状态。

## v0.5.1 管理修复更新 · 2026-11-04

通过完整119 Swift／9 Python／165原生检查／36图后，同一签名审查包更新常用路径，实际PID50476／build20261104T032707Z。旧包与两库备份 before-v051-20261104T033121Z；安装后表摘要不变，恢复3条草稿后JSON键顺序改变但解码值及revision相同，规范化两库内容一致。源码指纹、报告、Figma修复前备份与独立代码／数据恢复步骤见 [management-ui-fixes.md](management-ui-fixes.md)。本轮不包含真实API和跨应用插入复验。
