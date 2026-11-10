#!/usr/bin/env python3
"""Package the godot-ohos addon for distribution, mirroring godothub/godot-ohos layout.

Result layout (same as the upstream plugin release):

    godot-ohos/
      plugin.cfg
      godot_ohos_plugin.gd
      godot_ohos_platform.gd
      godot_ohos_exporter.gd
      godot_ohos_filter.gd
      ohos-icon.png
      README.md
      bin/openharmony_release_dual.zip
"""

import argparse
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ADDON = ROOT / "plugin/addons/godot-ohos"
TEMPLATE = ADDON / "bin/openharmony_release_dual.zip"

INCLUDE = [
    "plugin.cfg",
    "godot_ohos_plugin.gd",
    "godot_ohos_platform.gd",
    "godot_ohos_exporter.gd",
    "godot_ohos_filter.gd",
    "ohos-icon.png",
    "README.md",
    "README-ZH.md",
    "bin/openharmony_release_dual.zip",
    "bin/openharmony_release_dual.manifest.json",
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist/godot-ohos-4.7.2-arm64-x86_64.zip")
    args = parser.parse_args()

    missing = [name for name in INCLUDE if not (ADDON / name).exists()]
    if missing:
        raise SystemExit(f"Missing addon files: {missing}\nRun build_dual_template.py first.")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.output.exists():
        args.output.unlink()
    with zipfile.ZipFile(args.output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in INCLUDE:
            archive.write(ADDON / name, f"godot-ohos/{name}")

    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    args.output.with_suffix(".zip.sha256").write_text(f"{digest}  {args.output.name}\n", encoding="utf-8")
    print(f"Addon: {args.output} ({args.output.stat().st_size:,} bytes)")
    print(f"SHA256: {digest}")


if __name__ == "__main__":
    main()
