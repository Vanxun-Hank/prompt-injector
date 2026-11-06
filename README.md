# Prompt Injector

一个原生 macOS 菜单栏工具。把使用 Agent 的经验整理成可复用的 Prompt，随时从本地资料库找到并插入输入框，发送由你决定。

## 使用

- 在 Codex 普通主输入框点击文字区域，按 `⇧⌥Space` 打开浮窗。选好 Prompt 后复制，或在详情页按 `⌘Return` 插入原输入框。插入需要在系统设置中授权辅助功能，浏览和复制可直接使用。
- 菜单栏的「管理内容…」支持手动新增、编辑、搜索、分类和使用统计。也可以粘贴原文或链接，生成 Prompt 后逐条确认保存。未保存的条目会留在本地草稿。
- 浏览、搜索、复制和插入走本地资料库。联网取文、识别和生成由 DeepSeek 处理，API key 存在本机 Keychain。手动填写可离线完成。[整理与隐私说明](docs/llm.md)

## 从源码运行

在仓库根目录运行。需要 macOS 和 Swift 6 工具链，工程部署目标为 macOS 14。

```sh
bash scripts/build-app.sh
open 'build/Prompt Injector.app'
```

如果构建后无法插入，先确认授权对应当前应用。构建签名、系统权限与日志排查见 [开发文档](docs/development.md) 和 [故障排查](docs/debugging.md)。

资料库、草稿和使用记录存于 `~/Library/Application Support/Prompt Injector/`。备份时同时保留 `library.sqlite3` 和 `library-activity.sqlite3`。

## 开发

测试需要 Python 3。日常跑快速回归，PR 在 macOS 跑合并层。完整验收需要解锁桌面和截图权限。

```sh
python3 scripts/test-suite.py --tier fast
python3 scripts/test-suite.py --tier merge
python3 scripts/test-suite.py
```

[Agent 工作约定](AGENTS.md) · [测试命令与验收记录](docs/testing.md) · [产品路线图](docs/roadmap.md) · [变更记录](CHANGELOG.md)
