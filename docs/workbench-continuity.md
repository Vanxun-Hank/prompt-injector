# 工作台连续处理 · v0.6.1

2026-11-06。基线为 `vanxun/deepseek-mvp` 的 `2bd3921`、已安装 v0.6.0 build `20261104T041900Z`。本轮是现有流程修复，使用 Figma 的 V7 [工作台](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=387-1040)和[详情](https://www.figma.com/design/2HmvWbRy3wnjiMOwrbh6A6?node-id=388-1443)作视觉对照，未改写画布。

- 工作台垃圾桶与列表右键只移除草稿；手改内容和无法区分来源的旧候选先确认。确认与勾选仍相互独立。移除当前条切到相邻条，移除最后一条显示空状态。后台按稳定 ID 跳过排队条目；移除当前生成条目时取消它并继续其他任务，迟到结果失效。
- 「添加经验」在工作台右侧复用录入组件；点击旧条目可返回其编辑，待添加表单保留。停止识别保留本次输入，取消添加仅放弃本次录入，返回内容库/关闭前保存现有草稿。网络识别与生成仍串行，进行时可以查看和手改其他条目。
- 每篇新增的原文上下文和来源仅存一份，条目通过 ID 关联；旧条目读取原 `raw/source`。没有 SQL schema 迁移。保存时写入每条自己的来源，部分保存仅保留其余条目及仍在录入的草稿；全部保存后有「继续添加」「查看内容库」。
- 内容库所有筛选入口共用同一详情视图：复制、编辑、垃圾桶统一图标，复制在原位反馈且始终复制完整 Prompt。正式删除仍需要确认。

运行完整回归（隔离 App 包和临时资料库）：

```sh
PROMPT_INJECTOR_APP_OUTPUT="$PWD/build/Workbench-Continuity-Review/Prompt Injector.app" python3 scripts/test-suite.py
```

可在真实桌面用同一构建走鼠标和键盘路径。以下参数都须保留；`--verify-ui` 隔离 SQLite，`--qa-workbench` 保留管理窗口并使用固定识别/生成夹具：

```sh
"$PWD/build/Workbench-Continuity-Review/Prompt Injector.app/Contents/MacOS/PromptInjector" --verify-ui --qa-workbench
```

正式代码回滚使用 `git revert` 撤销本轮提交，或在独立工作区检出基线 `2bd3921`。应用可退出后替换为备份中的 v0.6.0。**旧版不会解析多来源草稿，不能直接用它继续处理新格式草稿**；先用新版完成处理，或备份当前双库并成对恢复升级前快照。新保存的正式条目仍使用旧 schema；代码或应用回滚不会撤销已保存条目，恢复旧数据库则会替换备份之后的编辑。Keychain 无需恢复。

## 验证与安装结果

最终完整套件 **130 Swift、11 Python、219 原生检查、45 张截图**通过。报告 `artifacts/tests/20261105T165642.770128Z/summary.json`，版本 v0.6.1，build `20261105T165652Z`，源码指纹 `c31d61e1adbd6185739468573b2043a63532fb9b891b3ae89f513549ff46fa47`。首次最小回归复现完成后空列表；原生复查发现未选分类 nil／空值及部分保存提示过期，最终截图检查完成文案不裁切。

隔离审查包 build `20261105T163633Z` 在真实 macOS 以鼠标右键、方向键、Return 和 Space 点走：录入识别、直接移除、手改确认、取消和追加第二篇、部分保存、回车取消移除、移除最后一条、空格继续添加、回库后重进恢复录入。随后修复提示和完成标签布局，最终完整套件覆盖这些修正。全部、分类、搜索入口的动作与三阅读页完整复制由原生套件验证；请求使用夹具，未调用真实 DeepSeek，未复验跨应用插入、物理断网、VoiceOver 或最低 macOS。

同一通过包已安装并从 `/Applications/Prompt Injector.app` 实际启动（PID17936），逐文件摘要与隔离包一致且签名通过。安装前备份 `~/Library/Application Support/Prompt Injector/Backups/before-continuity-v061-20261105T165956Z/` 包含旧 v0.6.0 与两库。安装时数据库比对一致，打开后恢复 10 条草稿；其后正式 App 记录 5 次明确的移除操作，剩余 5 条的全部字段未变。正式内容、分类、草稿归档及使用记录仍与安装前一致。保留这些实际操作后的状态，没有从备份回填。证据 `artifacts/workbench-continuity/installation.json` 与 `installed-workbench.png`。
