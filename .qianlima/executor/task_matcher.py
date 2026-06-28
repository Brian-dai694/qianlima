#!/usr/bin/env python3
"""千里马计划任务卡匹配器 - 从用户自然语言匹配任务卡"""
import re
from pathlib import Path
from typing import Optional, Dict, Any, List
import yaml


class TaskMatcher:
    """任务卡匹配器"""

    def __init__(self, task_cards_dir: Path):
        self.task_cards_dir = task_cards_dir
        self.task_cards: List[Dict[str, Any]] = []
        self._load_task_cards()

    def _load_task_cards(self):
        """加载所有任务卡"""
        for yaml_file in self.task_cards_dir.glob("*.yaml"):
            if yaml_file.name == "README.md":
                continue
            with open(yaml_file, 'r', encoding='utf-8') as f:
                data = yaml.safe_load(f)
                if data and 'task_card' in data:
                    card = data['task_card']
                    card['_source_file'] = yaml_file
                    self.task_cards.append(card)

    def match(self, user_input: str) -> Optional[Dict[str, Any]]:
        """
        匹配用户输入到任务卡

        Args:
            user_input: 用户自然语言输入

        Returns:
            匹配到的任务卡，未匹配返回 None
        """
        user_input_lower = user_input.lower().strip()

        # 直接匹配 plain_language_trigger
        for card in self.task_cards:
            triggers = card.get('plain_language_trigger', [])
            for trigger in triggers:
                if trigger.lower() in user_input_lower or user_input_lower in trigger.lower():
                    return card

        # 模糊匹配任务名称
        for card in self.task_cards:
            name = card.get('name', '')
            if name and name in user_input:
                return card

        # 关键词匹配
        keyword_map = {
            '竞品': 'competitor_comparison',
            'listing': 'listing_optimization',
            '优化': 'listing_optimization',
            '利润': 'profit_check',
            '关键词': 'keyword_monitoring',
            '排名': 'keyword_monitoring',
            '新品': 'product_discovery',
            '选品': 'product_discovery',
        }

        for keyword, task_id in keyword_map.items():
            if keyword in user_input_lower:
                for card in self.task_cards:
                    if card.get('id') == task_id:
                        return card

        return None

    def list_tasks(self) -> List[str]:
        """列出所有可用任务"""
        return [f"{card['id']}: {card['name']}" for card in self.task_cards]

    def get_task_by_id(self, task_id: str) -> Optional[Dict[str, Any]]:
        """根据 ID 获取任务卡"""
        for card in self.task_cards:
            if card.get('id') == task_id:
                return card
        return None
