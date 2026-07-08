#!/usr/bin/env python3
"""Small EverOS Cloud bridge for the Qianlima harness.

The script intentionally keeps EverOS behind one narrow doorway. Local
governance files remain the source of truth; EverOS is a recall layer.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from typing import Any


DEFAULT_USER_ID = os.getenv("QIANLIMA_EVEROS_USER_ID", "qianlima_owner")
DEFAULT_AGENT_ID = os.getenv("QIANLIMA_EVEROS_AGENT_ID", "qianlima_agent")
DEFAULT_SESSION_ID = os.getenv(
    "QIANLIMA_EVEROS_SESSION_ID",
    f"qianlima-{datetime.now(timezone.utc).strftime('%Y%m%d')}",
)


def load_client() -> Any:
    if not os.getenv("EVEROS_API_KEY"):
        raise SystemExit("EVEROS_API_KEY is not set. Set it in the environment; do not commit it.")

    try:
        from everos_cloud import EverOS
    except ImportError as exc:
        raise SystemExit("Missing dependency: install with `pip install everos-cloud`.") from exc

    return EverOS()


def now_ms() -> int:
    return int(time.time() * 1000)


def to_plain(value: Any) -> Any:
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, (list, tuple, set)):
        return [to_plain(item) for item in value]
    if isinstance(value, dict):
        return {str(key): to_plain(item) for key, item in value.items()}
    if hasattr(value, "model_dump"):
        return to_plain(value.model_dump())
    if hasattr(value, "dict"):
        return to_plain(value.dict())
    if hasattr(value, "__dict__"):
        return {
            key: to_plain(item)
            for key, item in vars(value).items()
            if not key.startswith("_")
        }
    return str(value)


def print_response(response: Any) -> None:
    print(json.dumps(to_plain(response), ensure_ascii=False, indent=2))


def build_filter(user_id: str, session_id: str | None = None) -> dict[str, Any]:
    filters: dict[str, Any] = {"user_id": user_id}
    if session_id:
        filters["AND"] = [{"session_id": session_id}]
    return filters


def cmd_search(args: argparse.Namespace) -> None:
    client = load_client()
    memories = client.v1.memories
    user_id = args.user_id or (DEFAULT_AGENT_ID if args.agent else DEFAULT_USER_ID)
    memory_types = args.memory_types
    if args.agent and not args.memory_types:
        memory_types = ["agent_memory"]
    if not memory_types:
        memory_types = ["episodic_memory", "profile"]

    response = memories.search(
        filters=build_filter(user_id, args.session_id),
        query=args.query,
        method=args.method,
        memory_types=memory_types,
        top_k=args.top_k,
        include_original_data=args.include_original_data,
    )
    print_response(response)


def cmd_get(args: argparse.Namespace) -> None:
    client = load_client()
    response = client.v1.memories.get(
        filters=build_filter(args.user_id, args.session_id),
        memory_type=args.memory_type,
        page=args.page,
        page_size=args.page_size,
    )
    print_response(response)


def cmd_add(args: argparse.Namespace) -> None:
    client = load_client()
    response = client.v1.memories.add(
        user_id=args.user_id,
        session_id=args.session_id,
        async_mode=not args.sync,
        messages=[
            {
                "role": args.role,
                "timestamp": args.timestamp or now_ms(),
                "content": args.content,
            }
        ],
    )
    print_response(response)


def cmd_add_agent(args: argparse.Namespace) -> None:
    client = load_client()
    message: dict[str, Any] = {
        "role": args.role,
        "timestamp": args.timestamp or now_ms(),
    }
    if args.role == "tool":
        if not args.tool_call_id:
            raise SystemExit("--tool-call-id is required when --role tool.")
        message["tool_call_id"] = args.tool_call_id
    if args.content:
        message["content"] = args.content

    response = client.v1.memories.agent.add(
        user_id=args.user_id,
        session_id=args.session_id,
        async_mode=not args.sync,
        messages=[message],
    )
    print_response(response)


def cmd_flush(args: argparse.Namespace) -> None:
    client = load_client()
    if args.agent:
        response = client.v1.memories.agent.flush(
            user_id=args.user_id or DEFAULT_AGENT_ID,
            session_id=args.session_id,
        )
    else:
        response = client.v1.memories.flush(
            user_id=args.user_id or DEFAULT_USER_ID,
            session_id=args.session_id,
        )
    print_response(response)


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="EverOS Cloud bridge for Qianlima memory.")
    sub = root.add_subparsers(dest="command", required=True)

    search = sub.add_parser("search", help="Search EverOS memories.")
    search.add_argument("query")
    search.add_argument("--user-id", default=None)
    search.add_argument("--session-id", default=None)
    search.add_argument("--agent", action="store_true", help="Search agent memory identity.")
    search.add_argument("--method", default="hybrid", choices=["keyword", "vector", "hybrid", "agentic"])
    search.add_argument("--memory-types", nargs="+", default=None)
    search.add_argument("--top-k", type=int, default=10)
    search.add_argument("--include-original-data", action="store_true")
    search.set_defaults(func=cmd_search)

    get = sub.add_parser("get", help="Get structured memories.")
    get.add_argument("--user-id", default=DEFAULT_USER_ID)
    get.add_argument("--session-id", default=None)
    get.add_argument("--memory-type", default="episodic_memory", choices=["episodic_memory", "profile", "agent_case", "agent_skill"])
    get.add_argument("--page", type=int, default=1)
    get.add_argument("--page-size", type=int, default=10)
    get.set_defaults(func=cmd_get)

    add = sub.add_parser("add", help="Add one personal memory message.")
    add.add_argument("--user-id", default=DEFAULT_USER_ID)
    add.add_argument("--session-id", default=DEFAULT_SESSION_ID)
    add.add_argument("--role", default="user", choices=["user", "assistant"])
    add.add_argument("--content", required=True)
    add.add_argument("--timestamp", type=int, default=None)
    add.add_argument("--sync", action="store_true", help="Use synchronous processing.")
    add.set_defaults(func=cmd_add)

    add_agent = sub.add_parser("add-agent", help="Add one agent trajectory message.")
    add_agent.add_argument("--user-id", default=DEFAULT_AGENT_ID)
    add_agent.add_argument("--session-id", default=DEFAULT_SESSION_ID)
    add_agent.add_argument("--role", default="assistant", choices=["user", "assistant", "tool"])
    add_agent.add_argument("--content", default=None)
    add_agent.add_argument("--tool-call-id", default=None)
    add_agent.add_argument("--timestamp", type=int, default=None)
    add_agent.add_argument("--sync", action="store_true", help="Use synchronous processing.")
    add_agent.set_defaults(func=cmd_add_agent)

    flush = sub.add_parser("flush", help="Flush accumulated memories.")
    flush.add_argument("--user-id", default=None)
    flush.add_argument("--session-id", default=DEFAULT_SESSION_ID)
    flush.add_argument("--agent", action="store_true")
    flush.set_defaults(func=cmd_flush)

    return root


def main() -> int:
    args = parser().parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
