# CLAUDE.md — 千里马 Git-safe 公开模板仓

Claude Code 进入本目录后，先执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

macOS / Linux（需先装 PowerShell 7）：

```bash
./start-qianlima.sh
```

然后读取：

```text
.qianlima/CODEX_BOOT.md
.qianlima/WORKSPACE_INDEX.md
```

## 工作区定位

这是千里马 Git-safe 公开模板仓，只能包含公开模板、治理文件、示例数据、脚本和脱敏文档。不要写入真实 token、账号、客户信息、ASIN 运营数据、成本台账、运行报告、截图或本地路径。

## Claude Code 行为规则

- 不要一次性读取整个工作区。
- 修改前先判断是否属于公开模板改动。
- 提交前必须运行 `.qianlima/scripts/verify-qianlima.ps1`。
- 遇到 GitHub Actions 红叉，优先本地复现 `.github/workflows/qianlima-verify.yml` 中的步骤。
- 每次开始任务先输出状态卡：工作区、场景、已加载来源、workflow/脚本、隐私风险/待验证。

## 任务路由

- README / 文档 / 翻译 → 编辑公开文档，并保持隐私边界
- 隐私剔除 / Git-safe → 跑 `verify-qianlima.ps1`
- CI 红叉 / 校验失败 → 本地复现 GitHub Actions 步骤
- 补 workflow / task-card → 只写 public-safe 模板定义
- 提交推送 → 先确认 `git status`、跑校验，再 commit/push

## 禁止提交

真实 `work.ws`、`data-sources.yaml`、usage ledger、decision log、报告、截图、token、账号、客户信息和本地路径。