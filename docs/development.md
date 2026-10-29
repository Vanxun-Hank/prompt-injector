# 开发、提交与回滚

## 从当前基线继续

`v0.1.0` 是首次公开的 Stage 1 基线。本项目在此之前没有 Git 历史；CHANGELOG 中的早期记录是开发事实，不代表存在对应旧提交。首次提交不能回到一个不存在的“上一版”，后续小版本可以明确回到这个基线。

后续 Agent 按顺序阅读：

1. `AGENTS.md`：范围与不可破坏的行为。
2. `PRODUCT.md`、`docs/roadmap.md`：已有能力和后续阶段。
3. `docs/stage2-plan.md`：下一项最小闭环、测试和回滚边界。
4. `docs/architecture.md`、`docs/bugs.md`：代码边界与已有回归。
5. `git log --oneline --decorate`、`git show <commit>`、`CHANGELOG.md`：实际变化。

不要把计划当作已实现，不为修复兼容性而移除“只写原目标、不发送、全文回读”的约束。question 框兼容问题已明确延期，不重新阻挡 Stage 2。

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

这是未来提交的模板，不是已完成新增功能的记录。正文写真实测试结果，失败或未测的部分明确标注。根因和测试入口写入 `docs/bugs.md`，发布行为写入 CHANGELOG。

用户已明确授权首次发布到 `main`。之后的分支、push 和发布仍按当次任务授权执行；不能把本次授权当成永远可自动发布。

## 回滚代码

共享的 main 优先用新增 revert 提交保留历史，不 force-push，不对用户未提交工作执行 reset --hard。

```sh
# 查看待回滚提交的范围，再用实际 SHA 替换占位值
git show <bad-commit>
git revert <bad-commit>
python3 scripts/test-suite.py
```

确认可用后再按授权推送。依赖同一个 schema 或 API 的一组提交应一起评估；不能只回滚其中一半。

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
