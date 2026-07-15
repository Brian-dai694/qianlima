# MANUS.md — 千里马私有运营工作区

Manus 进入本目录后，不要默认运行脚本。普通对话和同主题续问直接处理；只有需要本地业务数据、workflow、外部工具或高风险执行时，才进入千里马运行时：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\start-qianlima.ps1"
```

然后读取：

```text
.qianlima/MANUS_BOOT.md
.qianlima/WORKSPACE_INDEX.md
```

## 工作方式

这是私有运营工作区。可以读取真实业务上下文，但不得把私有数据复制到公开仓。

Manus 开始新的 L2/L3 业务任务时输出状态卡；L0、L1 和同主题续问不重复输出：

```text
千里马已启动
工作区：私有运营
当前场景：___
已加载来源：___
将使用 workflow：___
高风险/待验证：___
下一步：___
```

## 路由

- 关键词、排名、卡位 → `keyword_rank_scan` / `keyword_monitoring`
- 广告日报、广告花费 → `daily_ad_report`
- 利润、赚不赚钱 → `profit_check`
- Listing、标题、五点 → `listing_optimization`
- 竞品、ASIN 对比 → `competitor_comparison`
- 选品、品类判断 → `product_discovery`
- 资料整理、文档总结 → `knowledge_digest`

高风险动作必须先亮假设，再二次确认。

续问 `继续`、`下一步`、`还有吗`、`展开第 N 点`、`再详细一点`、`接着做`，且目标、数据源、风险和配置没有变化时，继承当前上下文，不重新启动、不重复读取、不单独记账。
