from __future__ import annotations

import platform
import subprocess
from pathlib import Path
from typing import Optional


def is_macos() -> bool:
    return platform.system() == "Darwin"


def _run_osascript(script: str) -> str:
    result = subprocess.run(
        ["osascript", "-e", script],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "osascript failed")
    return result.stdout.strip()


def pick_folder(prompt: str = "选择要管理的文件夹") -> Optional[str]:
    if not is_macos():
        return None
    script = f'result to POSIX path of (choose folder with prompt "{prompt}")'
    try:
        return _run_osascript(script)
    except RuntimeError:
        return None


def ask_choice(prompt: str, choices: list[str], default_choice: Optional[str] = None) -> Optional[str]:
    if not is_macos() or not choices:
        return None
    buttons = ", ".join(f'"{choice}"' for choice in choices)
    default_button = default_choice or choices[0]
    script = (
        f'display dialog "{prompt}" buttons {{{buttons}}} default button "{default_button}" '
        f'with icon note'
    )
    try:
        output = _run_osascript(script)
    except RuntimeError:
        return None
    for choice in choices:
        if choice in output:
            return choice
    return None


def show_message(message: str, title: str = "Qianlima Observer") -> None:
    if not is_macos():
        return
    safe_message = message.replace('"', '\\"')
    safe_title = title.replace('"', '\\"')
    script = f'display dialog "{safe_message}" with title "{safe_title}" buttons {{"OK"}} default button "OK"'
    try:
        _run_osascript(script)
    except RuntimeError:
        return


def show_text(title: str, body: str) -> None:
    if not is_macos():
        return
    safe_body = body.replace('"', '\\"')
    safe_title = title.replace('"', '\\"')
    script = f'display dialog "{safe_body}" with title "{safe_title}" buttons {{"OK"}} default button "OK"'
    try:
        _run_osascript(script)
    except RuntimeError:
        return


def default_output_path(prefix: str = "qianlima_observer") -> Path:
    desktop = Path.home() / "Desktop"
    if not desktop.exists():
        desktop = Path.home()
    return desktop / f"{prefix}.json"

