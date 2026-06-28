#!/usr/bin/env python3
"""测试执行器功能"""
import sys
from pathlib import Path

# 添加执行器目录到路径
executor_dir = Path(__file__).parent
sys.path.insert(0, str(executor_dir))

from task_matcher import TaskMatcher
from mcp_client import MCPClient
from workflow_runner import WorkflowRunner

def test_task_matcher():
    """测试任务匹配器"""
    print("=" * 60)
    print("测试 1: 任务匹配器")
    print("=" * 60)

    task_cards_dir = executor_dir.parent / "task-cards"
    matcher = TaskMatcher(task_cards_dir)

    print(f"\n加载任务卡: {len(matcher.task_cards)} 个")
    for task in matcher.list_tasks():
        print(f"  • {task}")

    # 测试匹配
    test_inputs = [
        "我要做竞品对比",
        "帮我算利润",
        "看看关键词排名",
        "优化 Listing"
    ]

    print(f"\n测试匹配:")
    for input_text in test_inputs:
        card = matcher.match(input_text)
        if card:
            print(f"  ✓ '{input_text}' → {card['id']}: {card['name']}")
        else:
            print(f"  ✗ '{input_text}' → 未匹配")

    print()

def test_mcp_client():
    """测试 MCP 客户端"""
    print("=" * 60)
    print("测试 2: MCP 客户端")
    print("=" * 60)

    client = MCPClient()

    print("\n调用 get_amazon_product:")
    result = client.get_amazon_product("B09B8V1LZ3", "amz_us")
    print(f"  结果: {result['title']}, ${result['price']}")

    print("\n调用 filter_niches:")
    niches = client.filter_niches(marketplace_id="US", search_volume_t90_min=10000)
    print(f"  结果: {len(niches)} 个利基市场")

    print("\n调用 read_lark_sheet:")
    data = client.read_lark_sheet("<TOKEN>", "Ad Daily", "2024-06-27")
    print(f"  结果: {len(data)} 行广告数据")

    usage = client.get_usage_summary()
    print(f"\n总调用: {usage['total_calls']} 次")
    print(f"  按工具: {usage['by_tool']}")

    print()

def test_workflow_runner():
    """测试 Workflow 执行器"""
    print("=" * 60)
    print("测试 3: Workflow 执行器")
    print("=" * 60)

    qianlima_root = executor_dir.parent
    client = MCPClient()
    runner = WorkflowRunner(qianlima_root, client)

    print(f"\n执行 daily_ad_report workflow:")
    result = runner.execute(
        'daily_ad_report',
        {'date': '2024-06-27', 'marketplace': 'US'}
    )

    if result['success']:
        print(f"\n✅ 执行成功")
        print(f"  用时: {result['duration_seconds']:.2f} 秒")
        print(f"  诊断: {len(result['diagnostics'])} 条")
        print(f"\n生成的报告预览:")
        print(result['report'][:500] + "...")
    else:
        print(f"\n❌ 执行失败: {result.get('error')}")

    print()

def main():
    print("\n千里马计划执行器 - 功能测试\n")

    try:
        test_task_matcher()
        test_mcp_client()
        test_workflow_runner()

        print("=" * 60)
        print("✅ 所有测试完成")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        return 1

    return 0

if __name__ == '__main__':
    sys.exit(main())
