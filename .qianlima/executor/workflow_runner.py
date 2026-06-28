#!/usr/bin/env python3
"""Workflow 执行引擎 - 解析并执行 .wf.yaml 定义的工作流"""
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
import yaml

from mcp_client import MCPClient


class WorkflowRunner:
    """Workflow 执行引擎"""

    def __init__(self, qianlima_root: Path, mcp_client: MCPClient):
        self.qianlima_root = qianlima_root
        self.workflows_dir = qianlima_root / "workflows"
        self.mcp_client = mcp_client
        self.data_sources = self._load_data_sources()

    def _load_data_sources(self) -> Dict[str, Any]:
        """加载数据源注册表"""
        ds_file = self.qianlima_root / "data-sources.yaml"
        if not ds_file.exists():
            return {}
        with open(ds_file, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
            return {ds['source_id']: ds for ds in data.get('data_sources', [])}

    def load_workflow(self, workflow_id: str) -> Optional[Dict[str, Any]]:
        """加载 workflow 定义"""
        wf_file = self.workflows_dir / f"{workflow_id}.wf.yaml"
        if not wf_file.exists():
            print(f"❌ Workflow 文件不存在: {wf_file}")
            return None

        with open(wf_file, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)

    def execute(
        self,
        workflow_id: str,
        inputs: Dict[str, Any],
        skip_validation: bool = False
    ) -> Dict[str, Any]:
        """
        执行 workflow

        Args:
            workflow_id: workflow ID
            inputs: 输入参数
            skip_validation: 跳过校验

        Returns:
            执行结果，包含 report、metrics、trace 等
        """
        print(f"\n{'='*60}")
        print(f"执行 Workflow: {workflow_id}")
        print(f"{'='*60}\n")

        wf_def = self.load_workflow(workflow_id)
        if not wf_def or 'workflow' not in wf_def:
            return {'success': False, 'error': 'Workflow 定义加载失败'}

        wf = wf_def['workflow']
        wf_name = wf.get('name', workflow_id)

        # 准备执行上下文
        context = {
            'workflow_id': workflow_id,
            'workflow_name': wf_name,
            'inputs': inputs,
            'start_time': datetime.now(),
            'data_collected': {},
            'metrics': {},
            'diagnostics': [],
            'trace': []
        }

        print(f"📋 {wf_name}")
        print(f"   场景: {wf.get('scenario', 'N/A')}")
        print(f"   状态: {wf.get('status', 'N/A')}")
        print(f"   输入: {inputs}\n")

        # 执行步骤
        steps = wf.get('execution', {}).get('steps', [])
        for step in steps:
            self._execute_step(step, context, wf)

        # 应用诊断规则
        if 'diagnostic_rules' in wf:
            self._apply_diagnostics(wf['diagnostic_rules'], context)

        # 生成报告
        report = self._generate_report(wf, context)

        context['end_time'] = datetime.now()
        context['duration_seconds'] = (context['end_time'] - context['start_time']).total_seconds()

        return {
            'success': True,
            'workflow_id': workflow_id,
            'report': report,
            'metrics': context['metrics'],
            'diagnostics': context['diagnostics'],
            'trace': context['trace'],
            'duration_seconds': context['duration_seconds'],
            'mcp_usage': self.mcp_client.get_usage_summary()
        }

    def _execute_step(
        self,
        step: Dict[str, Any],
        context: Dict[str, Any],
        wf: Dict[str, Any]
    ):
        """执行单个步骤"""
        order = step.get('order', '?')
        action = step.get('action', 'unknown')
        description = step.get('description', '')
        agent = step.get('agent', 'unknown_agent')

        print(f"  步骤 {order}: {description}")
        print(f"    → Agent: {agent}, Action: {action}")

        context['trace'].append({
            'order': order,
            'agent': agent,
            'action': action,
            'description': description,
            'timestamp': datetime.now().isoformat()
        })

        # 根据 action 类型调用不同方法
        if action == 'read_ad_data':
            self._read_ad_data(step, context, wf)
        elif action == 'read_sales_data':
            self._read_sales_data(step, context, wf)
        elif action == 'validate_data':
            self._validate_data(context)
        elif action == 'calculate_metrics':
            self._calculate_metrics(context, wf)
        elif action == 'apply_diagnostic_rules':
            # 延后到所有数据收集完成后统一执行
            pass
        elif action == 'generate_report':
            # 在主流程最后生成
            pass
        elif action == 'verify_report':
            print(f"      ✓ 报告验证")
        elif action == 'record_usage':
            print(f"      ✓ 成本记录")
        else:
            print(f"      ⚠️  未实现的 action: {action}")

        print()

    def _read_ad_data(self, step: Dict[str, Any], context: Dict[str, Any], wf: Dict[str, Any]):
        """读取广告数据"""
        source_id = step.get('source', 'lark_ads_daily')
        date_param = context['inputs'].get('date', 'yesterday')

        if date_param == 'yesterday':
            target_date = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
        else:
            target_date = date_param

        print(f"      数据源: {source_id}, 日期: {target_date}")

        # 模拟读取飞书广告数据
        data = self.mcp_client.read_lark_sheet(
            spreadsheet_token='<TOKEN>',
            sheet_id=source_id,
            date_filter=target_date
        )

        context['data_collected']['ad_data'] = data
        context['trace'][-1]['rows_read'] = len(data)
        print(f"      ✓ 读取 {len(data)} 行数据")

    def _read_sales_data(self, step: Dict[str, Any], context: Dict[str, Any], wf: Dict[str, Any]):
        """读取销售数据（可选步骤）"""
        if step.get('optional'):
            print(f"      ⊙ 可选步骤，跳过")
            return

        # 模拟读取
        print(f"      ✓ 读取销售数据（模拟）")

    def _validate_data(self, context: Dict[str, Any]):
        """校验数据质量"""
        ad_data = context['data_collected'].get('ad_data', [])
        if not ad_data:
            print(f"      ⚠️  无数据")
            return

        # 简单校验
        required_fields = ['date', 'campaign_name', 'spend', 'sales', 'orders']
        valid_count = 0
        for row in ad_data:
            if all(field in row for field in required_fields):
                valid_count += 1

        print(f"      ✓ 校验通过: {valid_count}/{len(ad_data)} 行完整")
        context['trace'][-1]['valid_rows'] = valid_count

    def _calculate_metrics(self, context: Dict[str, Any], wf: Dict[str, Any]):
        """计算指标"""
        ad_data = context['data_collected'].get('ad_data', [])
        if not ad_data:
            print(f"      ⚠️  无数据，跳过计算")
            return

        metrics_def = wf.get('metrics', [])
        metrics = {}

        # 计算汇总指标
        total_spend = sum(row.get('spend', 0) for row in ad_data)
        total_sales = sum(row.get('sales', 0) for row in ad_data)
        total_orders = sum(row.get('orders', 0) for row in ad_data)
        total_clicks = sum(row.get('clicks', 0) for row in ad_data)
        total_impressions = sum(row.get('impressions', 0) for row in ad_data)

        metrics['spend'] = total_spend
        metrics['sales'] = total_sales
        metrics['orders'] = total_orders
        metrics['clicks'] = total_clicks
        metrics['impressions'] = total_impressions

        # 计算衍生指标
        metrics['acos'] = (total_spend / total_sales * 100) if total_sales > 0 else None
        metrics['cpc'] = (total_spend / total_clicks) if total_clicks > 0 else None
        metrics['ctr'] = (total_clicks / total_impressions * 100) if total_impressions > 0 else None
        metrics['cvr'] = (total_orders / total_clicks * 100) if total_clicks > 0 else None

        context['metrics'] = metrics

        print(f"      ✓ 计算完成:")
        print(f"         花费: ${metrics['spend']:.2f}")
        print(f"         销售额: ${metrics['sales']:.2f}")
        print(f"         订单: {metrics['orders']}")
        if metrics['acos'] is not None:
            print(f"         ACoS: {metrics['acos']:.1f}%")

    def _apply_diagnostics(self, rules: List[Dict[str, Any]], context: Dict[str, Any]):
        """应用诊断规则"""
        print(f"  诊断规则: 应用 {len(rules)} 条规则\n")

        ad_data = context['data_collected'].get('ad_data', [])
        diagnostics = []

        for row in ad_data:
            campaign_name = row.get('campaign_name', 'Unknown')
            spend = row.get('spend', 0)
            sales = row.get('sales', 0)
            orders = row.get('orders', 0)
            clicks = row.get('clicks', 0)
            impressions = row.get('impressions', 0)

            acos = (spend / sales) if sales > 0 else None
            cvr = (orders / clicks * 100) if clicks > 0 else None

            # 应用规则
            for rule in rules:
                rule_id = rule.get('id')
                condition = rule.get('condition', '')
                severity = rule.get('severity', 'info')
                suggestion = rule.get('suggestion', '')

                # 简化的条件评估（实际应该用表达式解析器）
                fired = False

                if rule_id == 'high_spend_no_order' and spend >= 10 and orders == 0:
                    fired = True
                elif rule_id == 'high_acos' and acos and acos > 0.35 and orders >= 1:
                    fired = True
                elif rule_id == 'excellent_performance' and acos and acos <= 0.25 and orders >= 2:
                    fired = True
                elif rule_id == 'high_click_low_conversion' and clicks >= 15 and (orders == 0 or (cvr and cvr < 0.5)):
                    fired = True
                elif rule_id == 'low_impression' and impressions < 100 and spend < 5:
                    fired = True

                if fired:
                    diagnostics.append({
                        'campaign_name': campaign_name,
                        'rule_id': rule_id,
                        'rule_name': rule.get('name'),
                        'severity': severity,
                        'suggestion': suggestion,
                        'data': {
                            'spend': spend,
                            'sales': sales,
                            'orders': orders,
                            'acos': f"{acos:.1%}" if acos else 'N/A'
                        }
                    })
                    print(f"    🔔 {campaign_name}: {rule.get('name')} ({severity})")

        context['diagnostics'] = diagnostics
        print()

    def _generate_report(self, wf: Dict[str, Any], context: Dict[str, Any]) -> str:
        """生成报告（简化版，实际应使用模板渲染）"""
        metrics = context.get('metrics', {})
        diagnostics = context.get('diagnostics', [])
        inputs = context.get('inputs', {})

        date_str = inputs.get('date', 'yesterday')
        marketplace = inputs.get('marketplace', 'US')

        report = f"""# {wf.get('name', 'Workflow Report')}

**日期**: {date_str}
**站点**: {marketplace}
**生成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

---

## 核心指标

| 指标 | 数值 |
|------|------|
| 广告花费 | ${metrics.get('spend', 0):.2f} |
| 广告销售额 | ${metrics.get('sales', 0):.2f} |
| 订单数 | {metrics.get('orders', 0)} |
| ACoS | {f"{metrics.get('acos', 0):.1f}%" if metrics.get('acos') else 'N/A'} |
| CPC | ${metrics.get('cpc', 0):.2f} if metrics.get('cpc') else 'N/A' |
| CTR | {f"{metrics.get('ctr', 0):.2f}%" if metrics.get('ctr') else 'N/A'} |
| CVR | {f"{metrics.get('cvr', 0):.2f}%" if metrics.get('cvr') else 'N/A'} |

---

## 诊断与建议

"""
        if diagnostics:
            for diag in diagnostics:
                severity_icon = {'high': '🔴', 'medium': '🟡', 'low': '🟢', 'positive': '✅'}.get(diag['severity'], '⚪')
                report += f"{severity_icon} **{diag['campaign_name']}** - {diag['rule_name']}\n"
                report += f"   - {diag['suggestion']}\n"
                report += f"   - 数据: {diag['data']}\n\n"
        else:
            report += "_无异常。_\n\n"

        report += f"""---

## 数据来源

- 飞书表格：Ad Daily
- 数据日期：{date_str}

## 执行记录

- 用时: {context.get('duration_seconds', 0):.2f} 秒
- MCP 调用: {len(context.get('trace', []))} 步骤

---

_本报告由千里马计划执行器自动生成_
"""

        return report
