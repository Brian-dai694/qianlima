# AMZ-EVO 简单版融合说明

## 来源

本次参考本地目录：

`<本地工作目录>/amz-evo-harness`

该目录是一个较简单的 Amazon Operations Harness，包含：

- 亚马逊运营 Agent 提示词
- 长期记忆
- 工具描述
- 5 个评估任务
- 基础配置
- 报告输出样例
- evaluate -> analyze -> improve 的基础闭环

## 融合原则

千里马计划面对的是没有编辑、编程或数据管理基础的大众用户，所以不直接搬运 `amz-evo-harness` 的开发式结构。

本次只吸收三类最适合大众使用的内容：

1. 常见任务类型
2. 报告结构
3. 简单可理解的执行流程

不直接吸收：

- Python 工具实现
- 复杂 MCP 工具描述
- DeepSeek 专用运行方式
- 开发者式实验目录
- 需要用户粘贴 prompt 的流程

## 已融合的任务

| AMZ-EVO 原任务 | 千里马大众任务卡 | 用途 |
|---|---|---|
| 竞品对比分析 | `competitor_comparison` | 对比多个 ASIN 的价格、排名、评论、卖点 |
| Listing 优化诊断 | `listing_optimization` | 诊断标题、五点、关键词、A+ |
| 供应链利润测算 | `profit_check` | 测算售价、采购、费用、利润率 |
| 关键词监控报告 | `keyword_monitoring` | 监控 ASIN 的关键词排名变化 |
| 选品机会探索 | `product_discovery` | 判断品类或产品概念是否值得做 |

## 大众化调整

### 1. 从“评估任务”改成“任务卡”

AMZ-EVO 中的任务是给 Agent 评估用的。千里马改成给普通用户选择的任务卡。

用户不用说：

```text
执行 task-001-competitor-comparison。
```

只需要说：

```text
我要做竞品对比。
```

### 2. 从“工具调用”改成“你需要提供什么”

AMZ-EVO 更关注工具如何调用。千里马更关注用户要提供什么。

例如竞品对比只要求用户提供：

- 2-5 个竞品 ASIN
- 站点
- 自己产品 ASIN，可选

### 3. 从“实验结果”改成“最终报告”

AMZ-EVO 报告偏实验输出。千里马统一使用大众能读懂的报告结构：

```text
摘要
数据表
分析
建议
风险
待验证项
下一步
使用量与成本
```

### 4. 从“自动执行”改成“默认只建议”

千里马默认不会自动执行：

- 改价格
- 改广告竞价
- 改预算
- 改 Listing
- 下采购单
- 发外部消息

所有高风险动作都只给建议，执行前必须确认。

## 新增文件

### 任务卡

- `.qianlima/task-cards/competitor-comparison.yaml`
- `.qianlima/task-cards/listing-optimization.yaml`
- `.qianlima/task-cards/profit-check.yaml`
- `.qianlima/task-cards/keyword-monitoring.yaml`
- `.qianlima/task-cards/product-discovery.yaml`

### 报告模板

- `.qianlima/templates/competitor-comparison_template.md`
- `.qianlima/templates/listing-optimization_template.md`
- `.qianlima/templates/profit-check_template.md`
- `.qianlima/templates/keyword-monitoring_template.md`
- `.qianlima/templates/product-discovery_template.md`

### 流程文件

- `.qianlima/playbooks/amz-simple-playbook.yaml`

## 用户最常用入口

用户可以直接说：

```text
我要做竞品对比。
帮我优化这个 Listing。
算一下这个产品赚不赚钱。
跑一下这些关键词排名。
帮我判断这个品类能不能做。
```

Agent 应该自动匹配任务卡，并只问最少必要信息。

## 下一步

建议下一步实现一个简单的任务卡选择器：

```text
用户自然语言
  -> 匹配 task-cards
  -> 检查最少输入
  -> 选择模板
  -> 生成报告
  -> 记录日志和成本
```

第一版可以不接真实 API，只用用户上传的表格、已有文档和手动输入跑通流程。

