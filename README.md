# Prompt Injector

一个原生 macOS Prompt 快捷工具：从本地经验库选出需要的提示词，插入当前输入框，由你决定什么时候发送。

这个项目最初想解决的是：读到别人分享的 Agent 使用经验时，收藏很容易，真正用起来却很难。希望把经验原文和来源留下来，逐步整理成可重复使用的 Prompt，在写需求、编码、排查、审查和发布时随手调用。

长期目标是「收集经验 → LLM 辅助整理 → 人工审核 → 快捷调用」。**当前 v0.2.0 开发版已加入本地内容管理、使用统计与新版原生界面；LLM 整理尚未实现。**

## 当前能做什么

- `⇧⌥Space` 全局唤起或隐藏浮窗。
- 在同一个窗口内浏览「分类 → 标题与简述 → 完整详情」。
- 详情通过「Prompt / 经验与来源」切换，经验原文、来源和解释保持分开。
- 菜单栏进入「管理内容…」：新增、编辑、按标题和简述搜索；离开编辑或退出时保存本地草稿。管理窗口提供原生红黄绿关闭、最小化与放大按钮。
- 「使用统计」显示实际成功复制／插入的次数、趋势、分类分布和 Prompt 排行，从当前版本开始计次。
- 复制完整 Prompt，或用 `⌘Return` 插入唤起前的输入框，**不自动发送**。
- SQLite 本地保存内容，按分类、摘要和详情分层查询，调用过程不依赖网络。
- 采用 Figma 最新深色中性设计、渐变 Logo 和菜单栏模板图标，保留原生拖动、缩放、位置记忆、键盘导航和减少动态效果。

内置 5 个分类、7 条明确标注的项目示例。自动插入目前以 **Codex 普通主输入框**为验收目标；不承诺所有应用和所有输入框兼容。

## 界面

| 分类 | Prompt 列表 | 详情 |
| --- | --- | --- |
| ![分类](docs/images/categories.png) | ![Prompt 列表](docs/images/prompts.png) | ![详情](docs/images/detail.png) |

以上为 v0.1 历史运行截图，使用受控背景和项目示例内容；不代表当前 v0.2.0 新版画面。新版移植与验证状态见 [原生设计移植记录](docs/figma-integration.md)。

## 从源码构建

需要 macOS、Swift 6 工具链（Xcode / Command Line Tools）和 Git。测试工具另需 Python 3。工程部署目标为 macOS 14；目前实际验收环境为 macOS 27.2，最低版本兼容性尚未验证。

```sh
git clone https://github.com/Vanxun-Hank/prompt-injector.git
cd prompt-injector
bash scripts/build-app.sh
open 'build/Prompt Injector.app'
```

应用常驻菜单栏；打开管理窗口后以普通 macOS 应用显示品牌 Dock 图标，绿色按钮或 `⌃⌘F` 可进入独立桌面空间的原生全屏。当前提供源码构建，尚无公证过的安装包或自动更新。

实际 `.app` 位于 `~/Library/Application Support/Prompt Injector/Build/`；项目的 `build/Prompt Injector.app` 是指向它的链接。这样避免文件同步服务给应用追加属性后破坏签名。可用 `PROMPT_INJECTOR_APP_OUTPUT` 指定其他输出路径。

构建脚本会使用本机唯一有效的签名身份；也可通过 `PROMPT_INJECTOR_SIGN_IDENTITY` 明确指定。没有唯一身份时使用临时签名，重新构建后可能需要重新授权辅助功能。证书、私钥不放进仓库。

## 第一次使用

1. 打开应用，从菜单栏进入「辅助功能权限…」。
2. 在系统设置中开启 **Prompt Injector** 的辅助功能权限；认证操作由你完成。无需授予整个项目目录权限。
3. 回到 Codex 的普通主输入框，点击输入区域，确认文字光标在里面。
4. 按 `⇧⌥Space`，逐层选择分类和 Prompt。
5. 在详情页按 `⌘Return`，或点击右下插入图标。文字留在原输入框，检查后再自行发送。

不授予辅助功能权限也可以浏览和复制。权限缺失、目标失效或内容变化时，应用会拒绝自动插入并保留复制操作。

### 快捷键

| 快捷键 | 行为 |
| --- | --- |
| `⇧⌥Space` | 全局显示 / 隐藏；菜单可切换为 `⌃⇧Space` |
| `↑` / `↓` | 选择分类或条目 |
| `Return` | 前两层进入下一级；详情页不执行插入 |
| `Shift + Return` | 返回上一级；分类页不操作 |
| `Escape` | 返回上一级；分类页隐藏 |
| `⌘Return` | 详情页插入当前 Prompt |

隐藏、返回时保留当前进程内的页面、选择和滚动。窗口尺寸、位置和快捷键设置跨启动保留。默认窗口 620 × 520 pt，最小 360 × 300 pt。

## 数据与隐私

- 资料库：`~/Library/Application Support/Prompt Injector/library.sqlite3`。
- 草稿与使用记录：同目录 `library-activity.sqlite3`；备份时一起保留。代码回滚不会恢复已编辑内容。
- 日志：`~/Library/Logs/Prompt Injector/`，本地轮转保存，约 4 MiB 上限。
- 构建标识：`build/build-info.json`，含构建 ID、源码指纹和 Git revision。

首次建库在事务内导入内置示例，之后重启不重复导入、不覆盖已有数据。损坏或版本较新的库会报错，不自动删除重建。

当前版本不接入账号、后端、LLM 或云端同步。日志记录阶段、错误代码、长度与耗时，不记录 Prompt、输入框正文或剪贴板数据；不会上传日志。数据库、运行日志及原始测试产物均不随 Git 提交。

## 故障排查

- **需要辅助功能权限**：确认授权的是当前构建的 `.app`。临时签名更新后可能需要移除旧条目，再添加当前应用。
- **未选中输入框**：收起浮窗，点击真正的文字输入区域，再重新唤起。切换浮窗里的条目不会重新捕获目标。
- **原输入框失效 / 内容变化**：返回目标输入框重新唤起；应用不会猜测另一个输入框并写入。
- **未能确认插入结果**：先检查原输入框，勿重复插入。只有完整回读一致才确认成功。

Codex question 自由回答框存在连续空行回读差异，列为后续兼容性事项，不属于 v0.1 主输入框验收范围。

```sh
python3 scripts/read-logs.py --last 80
python3 scripts/read-logs.py --level error --last 20
```

完整排查方法见 [debugging.md](docs/debugging.md)。反馈问题时请提供版本、操作步骤和错误代码，先检查并去除私人信息。

## 开发与测试

```sh
# 完整套件：单元测试、工具测试、构建签名、原生窗口检查和截图
python3 scripts/test-suite.py

# 无可用桌面时的部分检查（仍需 macOS）
python3 scripts/test-suite.py --headless
```

完整套件需要解锁桌面及截图权限。结果写入本地 `artifacts/tests/`；`--headless` 不替代真实窗口与跨应用验收。v0.1 验收基线为 **36 Swift + 6 Python + 69 原生检查**；断网插入、未授权拒绝/复制、原目标失效另外经过真实用户操作验证。v0.2.0 新版完整套件为 **48 Swift + 7 Python + 107 原生检查、19 张截图**，包含原生窗口按钮的实际操作；本轮未重复真实 Codex 跨应用插入。详见 [测试案例](docs/testing.md)、[移植记录](docs/figma-integration.md) 和 [Stage 1 验收摘要](docs/stage1-acceptance.md)。

## 路线图与维护

| 阶段 | 目标 | 状态 |
| --- | --- | --- |
| Stage 1 · v0.1 | 本地浏览、复制和 Codex 主输入框插入 | 当前环境验收完成 |
| Stage 2 · v0.2.x | 自己新增、编辑、搜索、备份与恢复内容 | 新增／编辑／管理页搜索及统计已实现并通过原生回归；导入导出与删除未实现 |
| Stage 3 · v0.3 | LLM 辅助整理经验，人工确认后保存 | 计划中 |
| Stage 4 · v0.4 | 云端正式内容与离线缓存同步 | 计划中 |

后续开发先读 [AGENTS.md](AGENTS.md)。项目背景在 [PRODUCT.md](PRODUCT.md)，代码边界在 [架构文档](docs/architecture.md)，设计规则在 [DESIGN.md](DESIGN.md)。每个可用小版本单独提交、运行回归套件、留下变更与回滚说明；见 [开发与回滚约定](docs/development.md) 和 [CHANGELOG](CHANGELOG.md)。

许可证尚未指定。
