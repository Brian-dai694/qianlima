# MANUS.md — 千里马 Git-safe 公开模板仓

Manus 进入本目录后，先运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

然后读取：

```text
.qianlima/MANUS_BOOT.md
.qianlima/WORKSPACE_INDEX.md
```

## 工作方式

这是 Git-safe 公开模板仓，只能处理公开模板、治理文件、脚本、README 和脱敏示例。不得写入真实业务数据。

Manus 每次开始任务必须先输出状态卡：

```text
千里马已启动
工作区：Git-safe 公开模板
当前场景：___
已加载来源：___
将使用 workflow/脚本：___
隐私风险/待验证：___
下一步：___
```

## 路由

- README / 文档 / 翻译 → 修改公开文档
- 隐私剔除 / Git-safe → 运行 `verify-qianlima.ps1`
- CI 红叉 / 校验失败 → 复现 `.github/workflows/qianlima-verify.yml`
- workflow / task-card → 只写 public-safe 模板
- 提交推送 → 先校验，再 commit / push

禁止提交 token、账号、客户信息、真实 ASIN 数据、usage ledger、decision log、报告、截图和本地路径。