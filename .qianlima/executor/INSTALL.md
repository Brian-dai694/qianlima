# 千里马计划执行器 - 安装与使用指南

## 当前状态

✅ **已完成**：
- 任务卡匹配器（`task_matcher.py`）- 从自然语言匹配任务卡
- 主执行器框架（`executor.py`）- CLI + 交互模式
- 项目结构搭建

⚠️ **待实现**（需要 Python 环境）：
- Workflow 执行引擎
- MCP 工具集成（pangolinfo、sorftime）
- 模板渲染器
- 成本追踪

## 安装步骤

### 1. 安装 Python（如果尚未安装）

Windows 上推荐两种方式：

**方式 A - 从 python.org 下载**：
```powershell
# 访问 https://www.python.org/downloads/
# 下载 Python 3.11+ 安装包，安装时勾选 "Add Python to PATH"
```

**方式 B - 使用 winget**：
```powershell
winget install Python.Python.3.11
```

验证安装：
```powershell
python --version
# 应显示：Python 3.11.x 或更高
```

### 2. 安装依赖

```powershell
cd "E:\work speac\千里马计划\千里马计划-公开版\.qianlima\executor"
pip install -r requirements.txt
```

### 3. 配置环境变量（可选）

如需调用 Claude API（当前框架预留了接口但未实现）：
```powershell
# 创建 .env 文件
echo "ANTHROPIC_API_KEY=your_api_key_here" > .env
```

## 使用方式

### 交互模式（推荐新手）

```powershell
cd "E:\work speac\千里马计划\千里马计划-公开版\.qianlima\executor"
python executor.py
```

会看到：
```
============================================================
千里马计划 - 任务执行器
============================================================

可用任务：
  • competitor_comparison: 竞品对比
  • listing_optimization: Listing 优化诊断
  • profit_check: 利润测算
  • keyword_monitoring: 关键词监控
  • product_discovery: 新品机会探索

输入 'quit' 或 'exit' 退出

你想做什么？>
```

然后输入自然语言，例如：
- `我要做竞品对比`
- `帮我算利润`
- `看看关键词排名`

### CLI 模式（适合脚本调用）

```powershell
# 竞品对比
python executor.py --task "竞品对比" --asin "B09B8V1LZ3,B0CRMZHDG8" --marketplace US

# 利润测算
python executor.py --task "利润测算" --marketplace US

# 关键词监控
python executor.py --task "关键词监控" --asin "B09B8V1LZ3" --keywords "wireless earbuds,noise cancelling"
```

## 当前限制

由于 Workflow 执行器尚未实现，执行器当前只能：
1. ✅ 匹配任务卡
2. ✅ 收集用户输入
3. ✅ 显示任务卡定义的步骤
4. ❌ **实际执行 workflow 步骤（待实现）**

## 下一步开发计划

1. **Workflow 执行器**（`workflow_runner.py`）
   - 解析 `.qianlima/workflows/*.wf.yaml`
   - 按步骤执行 data_agent / analysis_agent / execution_agent
   - 调用 MCP 工具获取数据

2. **MCP 客户端**（`mcp_client.py`）
   - 封装 pangolinfo MCP 工具（`get_amazon_product`, `filter_niches` 等）
   - 封装 sorftime MCP 工具（关键词排名）
   - 数据源认证管理

3. **模板渲染器**（`template_renderer.py`）
   - 读取 `.qianlima/templates/*.md`
   - 用 Jinja2 渲染数据到模板
   - 生成最终报告到 `reports/`

4. **成本追踪器**（`usage_tracker.py`）
   - 记录 API 调用次数
   - 追踪 Token 使用量
   - 写入 `usage-ledger/*.yaml`

## 测试用例

安装完成后可以这样测试：

```powershell
# 测试 1: 任务匹配
python executor.py --task "我要做竞品对比"
# 预期：匹配到 competitor_comparison 任务卡

# 测试 2: 交互模式
python executor.py
# 然后输入: 帮我优化 Listing
# 预期：匹配到 listing_optimization 任务卡并收集输入
```

## 故障排查

**问题 1：`python: command not found`**
- 检查 Python 是否已安装：`python --version`
- 如未安装，参考上方"安装步骤"

**问题 2：`ModuleNotFoundError: No module named 'yaml'`**
- 运行：`pip install -r requirements.txt`

**问题 3：中文乱码**
- 确保终端编码为 UTF-8
- PowerShell 中运行：`[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`

## 与启动脚本集成（未来）

可以在 `start-qianlima.ps1` 中添加执行器检查：
```powershell
$ExecutorPath = Join-Path $QianlimaRoot 'executor/executor.py'
if (Test-Path $ExecutorPath) {
  Write-Host 'Executor available. Run: python .qianlima/executor/executor.py'
}
```
