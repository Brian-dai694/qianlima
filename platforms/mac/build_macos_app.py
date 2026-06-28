from __future__ import annotations

import os
import shutil
import stat
import textwrap
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DIST = ROOT / "dist"
APP = DIST / "QianlimaObserver.app"
CONTENTS = APP / "Contents"
MACOS = CONTENTS / "MacOS"
RESOURCES = CONTENTS / "Resources"


def main() -> None:
    DIST.mkdir(exist_ok=True)
    MACOS.mkdir(parents=True, exist_ok=True)
    RESOURCES.mkdir(parents=True, exist_ok=True)
    bundle_pkg = RESOURCES / "qianlima_observer"
    shutil.rmtree(bundle_pkg, ignore_errors=True)
    shutil.copytree(ROOT / "qianlima_observer", bundle_pkg)
    icon_file = RESOURCES / "QianlimaObserverIcon.icns"
    if not icon_file.exists():
        icon_file.write_bytes(b"")

    (CONTENTS / "Info.plist").write_text(info_plist(), encoding="utf-8")
    (MACOS / "QianlimaObserver").write_text(executable_script(), encoding="utf-8")
    os.chmod(MACOS / "QianlimaObserver", stat.S_IRWXU | stat.S_IRGRP | stat.S_IROTH)

    print(APP)


def info_plist() -> str:
    return textwrap.dedent(
        """\
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleName</key>
          <string>QianlimaObserver</string>
          <key>CFBundleDisplayName</key>
          <string>QianlimaObserver</string>
          <key>CFBundleIdentifier</key>
          <string>com.qianlima.observer</string>
          <key>CFBundleVersion</key>
          <string>1.0.0</string>
          <key>CFBundleShortVersionString</key>
          <string>1.0.0</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>CFBundleExecutable</key>
          <string>QianlimaObserver</string>
          <key>CFBundleIconFile</key>
          <string>QianlimaObserverIcon</string>
          <key>LSUIElement</key>
          <true/>
        </dict>
        </plist>
        """
    )


def executable_script() -> str:
    return textwrap.dedent(
        """\
        #!/bin/bash
        set -euo pipefail
        APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
        RESOURCES_DIR="$APP_DIR/Resources"
        PYTHON_BIN="$(command -v python3 || true)"
        if [[ -z "$PYTHON_BIN" ]]; then
          osascript -e 'display dialog "python3 not found" buttons {"OK"} default button "OK"'
          exit 1
        fi
        export PYTHONPATH="$RESOURCES_DIR${PYTHONPATH:+:$PYTHONPATH}"
        exec "$PYTHON_BIN" -m qianlima_observer.cli . --interactive
        """
    )


if __name__ == "__main__":
    main()

