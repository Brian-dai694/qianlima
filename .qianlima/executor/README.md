# 千里马计划任务执行器

Python 实现的任务卡执行引擎，支持：
- 自然语言任务匹配
- Workflow 编排
- MCP 工具集成
- 模板渲染
- 成本追踪

## 安装

```bash
pip install -r requirements.txt
```

## 使用

```bash
# 交互模式
python executor.py

# 直接执行
python executor.py --task "我要做竞品对比" --asin "B09B8V1LZ3,B0CRMZHDG8" --marketplace US
```

## 架构

```
executor.py          主入口，CLI 解析
task_matcher.py      任务卡匹配
workflow_runner.py   Workflow 执行
template_renderer.py 报告生成
mcp_client.py        MCP 工具调用封装
usage_tracker.py     成本追踪
```
