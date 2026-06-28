#!/usr/bin/env python3
"""千里马计划主执行器"""
import sys
import argparse
from pathlib import Path
from typing import Dict, Any, Optional
import yaml

from task_matcher import TaskMatcher
from mcp_client import MCPClient
from workflow_runner import WorkflowRunner


class QianlimaExecutor:
    """千里马计划任务执行器"""

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.qianlima_root = project_root / ".qianlima"
        self.task_cards_dir = self.qianlima_root / "task-cards"

        # 初始化组件
        self.task_matcher = TaskMatcher(self.task_cards_dir)
        self.mcp_client = MCPClient()
        self.workflow_runner = WorkflowRunner(self.qianlima_root, self.mcp_client)

        # 加载工作区配置
        self.work_ws = self._load_yaml(self.qianlima_root / "work.ws")

    def _load_yaml(self, path: Path) -> Dict[str, Any]:
        """加载 YAML 文件"""
        if not path.exists():
            return {}
        with open(path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f) or {}

    def interactive_mode(self):
        """交互模式"""
        print("=" * 60)
        print("千里马计划 - 任务执行器")
        print("=" * 60)
        print("\n可用任务：")
        for task in self.task_matcher.list_tasks():
            print(f"  • {task}")
        print("\n输入 'quit' 或 'exit' 退出\n")

        while True:
            try:
                user_input = input("你想做什么？> ").strip()

                if user_input.lower() in ['quit', 'exit', 'q']:
                    print("再见！")
                    break

                if not user_input:
                    continue

                # 匹配任务卡
                task_card = self.task_matcher.match(user_input)

                if not task_card:
                    print(f"❌ 未匹配到任务。请尝试：")
                    for task in self.task_matcher.list_tasks():
                        print(f"  • {task}")
                    continue

                print(f"\n✓ 匹配到任务：{task_card['name']}")
                print(f"  ID: {task_card['id']}")
                print(f"  适用场景: {task_card.get('when_to_use', '无描述')}")

                # 收集输入
                print(f"\n需要提供的信息：")
                user_needs = task_card.get('user_needs_to_provide', [])
                for item in user_needs:
                    print(f"  • {item}")

                inputs = self._collect_inputs(task_card)

                if inputs:
                    print(f"\n收集到的输入：")
                    for key, value in inputs.items():
                        print(f"  {key}: {value}")

                    # 执行 workflow
                    print(f"\n开始执行 workflow...")
                    result = self._execute_workflow(task_card, inputs)

                    if result.get('success'):
                        print(f"\n✅ 执行成功！")
                        print(f"\n{'='*60}")
                        print(result['report'])
                        print(f"{'='*60}")

                        # 显示统计
                        print(f"\n📊 执行统计:")
                        print(f"  用时: {result.get('duration_seconds', 0):.2f} 秒")
                        mcp_usage = result.get('mcp_usage', {})
                        print(f"  MCP 调用: {mcp_usage.get('total_calls', 0)} 次")
                    else:
                        print(f"\n❌ 执行失败: {result.get('error', '未知错误')}")

                print("\n" + "=" * 60 + "\n")

            except KeyboardInterrupt:
                print("\n\n再见！")
                break
            except Exception as e:
                print(f"❌ 错误：{e}")
                import traceback
                traceback.print_exc()

    def _execute_workflow(self, task_card: Dict[str, Any], inputs: Dict[str, Any]) -> Dict[str, Any]:
        """执行任务卡对应的 workflow"""
        task_id = task_card.get('id')

        # 从 workflow-index.yaml 查找对应的 workflow
        workflow_index = self._load_yaml(self.qianlima_root / "workflow-index.yaml")
        workflows = workflow_index.get('workflows', [])

        # 匹配 workflow
        target_workflow = None
        for wf in workflows:
            if wf.get('id') == task_id or task_id in wf.get('id', ''):
                target_workflow = wf
                break

        if not target_workflow:
            # 如果没有精确匹配，尝试通过场景匹配
            scenario = task_card.get('scenario', '')
            for wf in workflows:
                if wf.get('scenario') == scenario:
                    target_workflow = wf
                    break

        if not target_workflow:
            return {
                'success': False,
                'error': f'未找到 {task_id} 对应的 workflow 定义'
            }

        workflow_id = target_workflow['id']
        print(f"  → 匹配到 workflow: {workflow_id}")

        # 执行 workflow
        return self.workflow_runner.execute(workflow_id, inputs)

    def _collect_inputs(self, task_card: Dict[str, Any]) -> Dict[str, Any]:
        """收集任务所需输入"""
        inputs = {}
        user_needs = task_card.get('user_needs_to_provide', [])

        # 简化版：直接询问
        for need in user_needs:
            need_str = str(need).strip()
            value = input(f"  {need_str}: ").strip()
            if value:
                # 简单解析字段名
                if 'asin' in need_str.lower():
                    inputs['asins'] = [a.strip() for a in value.split(',')]
                elif '站点' in need_str or 'marketplace' in need_str.lower():
                    inputs['marketplace'] = value.upper()
                elif '关键词' in need_str or 'keyword' in need_str.lower():
                    inputs['keywords'] = [k.strip() for k in value.split(',')]
                else:
                    inputs[need_str] = value

        return inputs

    def execute_task(self, task_input: str, **kwargs):
        """执行单个任务（CLI 模式）"""
        task_card = self.task_matcher.match(task_input)

        if not task_card:
            print(f"❌ 未找到匹配的任务：{task_input}")
            print(f"\n可用任务：")
            for task in self.task_matcher.list_tasks():
                print(f"  • {task}")
            return 1

        print(f"✓ 匹配到任务：{task_card['name']}")

        # 构建输入
        inputs = {
            'date': kwargs.get('date', 'yesterday'),
            'marketplace': kwargs.get('marketplace', 'US')
        }

        if kwargs.get('asins'):
            inputs['asins'] = kwargs['asins']
        if kwargs.get('keywords'):
            inputs['keywords'] = kwargs['keywords']

        # 执行 workflow
        result = self._execute_workflow(task_card, inputs)

        if result.get('success'):
            print(f"\n✅ 执行成功！")
            print(f"\n{'='*60}")
            print(result['report'])
            print(f"{'='*60}\n")
            return 0
        else:
            print(f"❌ 执行失败: {result.get('error')}")
            return 1


def main():
    parser = argparse.ArgumentParser(description='千里马计划任务执行器')
    parser.add_argument('--task', help='任务描述（自然语言）')
    parser.add_argument('--asin', help='ASIN 列表（逗号分隔）')
    parser.add_argument('--marketplace', default='US', help='站点（默认 US）')
    parser.add_argument('--keywords', help='关键词列表（逗号分隔）')
    parser.add_argument('--date', default='yesterday', help='数据日期（默认 yesterday）')

    args = parser.parse_args()

    # 定位项目根目录（从 .qianlima/executor/ 往上两级）
    executor_dir = Path(__file__).parent
    project_root = executor_dir.parent.parent

    executor = QianlimaExecutor(project_root)

    if args.task:
        # CLI 模式
        sys.exit(executor.execute_task(
            args.task,
            asins=args.asin.split(',') if args.asin else None,
            marketplace=args.marketplace,
            keywords=args.keywords.split(',') if args.keywords else None,
            date=args.date
        ))
    else:
        # 交互模式
        executor.interactive_mode()


if __name__ == '__main__':
    main()
