# macOS 应用程序安装 · 2026-11-04

Prompt Injector 已是 Swift＋AppKit 原生 `.app`；原来位于隐藏的开发输出目录，因此 Finder 的「应用程序」中没有它。本轮将已验证的 v0.6.0 原包安装到 `/Applications/Prompt Injector.app`，注册 Launch Services，并从该绝对路径实际启动。

旧入口 `~/Library/Application Support/Prompt Injector/Build/Prompt Injector.app` 改为指向 `/Applications/Prompt Injector.app` 的符号链接，后续沿用现有默认构建路径时写入同一份应用。没有新增配置、菜单、开机启动或产品功能。审查构建仍必须通过 `PROMPT_INJECTOR_APP_OUTPUT` 使用独立路径，不能在正式实例运行时构建覆盖它。

## 本轮验证

- 安装前确认没有运行实例，备份旧包和成对 SQLite；暂存包、最终包及旧入口均通过 `codesign --verify --strict`。安装后的逐文件 SHA256 与安装前包相同，没有重新编译或改签名。
- v0.6.0、build `20261104T041900Z`、source `9c54dd763ca0a67d10dc8e15d1d8f4a990911aa8623292d482c9e1d7cd0fe264`；实际 PID5511 从 `/Applications/Prompt Injector.app/Contents/MacOS/PromptInjector` 运行。
- 新位置实际日志显示辅助功能 `trusted=true`、全局快捷键注册成功。打开管理窗口并恢复原3条草稿；没有生成或正式保存。
- 安装及启动前后，主库和伴随库全部用户表规范化字段摘要相同：分类7、正式内容0、使用事件5、经验草稿1。没有改动 Keychain、恢复旧内容或写入测试夹具。
- 本轮只移动同一份通过完整回归的应用、补安装记录，没有改动客户端代码，因此未重跑完整套件。该包先前的125 Swift／10 Python／199原生检查／43图结果见 [V7 移植记录](management-v7-implementation.md)，属于上一轮实测。
- 原生工具未能取得 Finder 窗口，未声称在 Finder／Launchpad 内实际点击验收；文件路径、签名、系统注册及从新路径启动已验证。真实 API、跨应用插入和物理断网本轮未验收。

本机证据保存在忽略的 `artifacts/installation/applications/report.json` 与 `installed-app.png`。安装前备份为 `~/Library/Application Support/Prompt Injector/Backups/before-applications-20261104T095300Z/`，包含 v0.6.0 包和两库。

## 提交与回滚

新版功能提交 `840940a` 记录卡片内容库、原位编辑、统一工作台、验证结果和回滚边界；前一修复提交为 `61aa83c`。本轮另提交安装及恢复记录，再将这些提交推送到现有 `vanxun/deepseek-mvp` 分支。未合并 main、未重写历史，不包含既有未提交的 AGENTS.md、README.md 和 stage2-plan.md。

如果只需撤回 UI 改动，在干净的独立工作区使用 `git revert 840940a`，回到 v0.5.1 行为，并完成回归后重新安装。不要对当前脏工作区执行 reset --hard。该普通提交不使用 merge mainline 参数。

如果需要恢复应用包：先正常退出所有实例，另存当前包；从 `before-v060-20261104T041802Z/Prompt Injector.app` 恢复 v0.5.1 到 `/Applications/Prompt Injector.app`，保持旧入口链接指向该位置，重新验证签名并注册、打开。回退本轮安装位置时，先退出，将当前 `/Applications` 包移入单独备份，移除旧入口符号链接，再从 `before-applications-20261104T095300Z/Prompt Injector.app` 恢复到原开发路径；只移除链接不删除其指向的应用。注册恢复后的绝对路径。

**代码或应用回滚不恢复数据。** 两库与应用安装位置无关；通常无需恢复数据库。只有明确需要恢复某时点资料时，退出所有实例、先备份当前状态，再成对恢复 `library.sqlite3` 与 `library-activity.sqlite3`，这会替换备份之后的编辑。Keychain 独立保留。
