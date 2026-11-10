#!/usr/bin/env python3
"""Build the dual-architecture OHOS native template used by the godot-ohos addon.

Both architectures live in one template archive, so a single addon ships
ARM64 and x86_64 together. The Godot export preset then selects which
architectures are kept in the generated OHOS project.
"""

import argparse
import hashlib
import json
import re
import shutil
import sys
import zipfile
from pathlib import Path

from verify_ohos import verify_library, verify_template

ROOT = Path(__file__).resolve().parent
BIN = ROOT / "bin"
ADDON = ROOT / "plugin/addons/godot-ohos"
TEMPLATE_NAME = "openharmony_release_dual.zip"

ARCHES = {
    "arm64-v8a": ("libgodot.openharmony.template_release.arm64.so", 183),
    "x86_64": ("libgodot.openharmony.template_release.x86_64.so", 62),
}


def stage_project(staging: Path) -> Path:
    """Copy the OHOS project template without any native libraries."""
    project = staging / "project"
    template = ROOT / "platform/openharmony/template"
    shutil.copytree(template, project, ignore=shutil.ignore_patterns("libs"))
    include_dir = project / "entry/src/main/cpp/include"
    include_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(
        ROOT / "platform/openharmony/bridge_openharmony.h",
        include_dir / "bridge_openharmony.h",
    )
    return project


def build(output: Path) -> dict:
    libraries = {}
    for abi, (library_name, machine) in ARCHES.items():
        library = BIN / library_name
        if not library.exists():
            raise SystemExit(f"Missing engine library: {library}")
        verify_library(library, abi)
        libraries[abi] = library

    staging = output.parent / f".{output.stem}.staging"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)

    try:
        project = stage_project(staging)
        for abi, library in libraries.items():
            target = project / "entry/libs" / abi
            target.mkdir(parents=True, exist_ok=True)
            shutil.copy2(library, target / "libgodot.so")

        profile = project / "entry/build-profile.json5"
        content = profile.read_text(encoding="utf-8")
        filters = ", ".join(f'"{abi}"' for abi in libraries)
        content, count = re.subn(r'"abiFilters"\s*:\s*\[[^\]]*\]', f'"abiFilters": [{filters}]', content)
        if count != 1:
            raise SystemExit("Could not update abiFilters in entry/build-profile.json5")
        profile.write_text(content, encoding="utf-8")

        if output.exists():
            output.unlink()
        shutil.make_archive(str(output.with_suffix("")), "zip", root_dir=project)
    finally:
        shutil.rmtree(staging, ignore_errors=True)

    verify_template(output)
    manifest = {
        "engine_version": "4.7.2",
        "native_target": "template_release",
        "architectures": list(libraries),
        "renderer": "vulkan-and-opengl-es3",
        "template": output.name,
        "libraries": {
            abi: {
                "sha256": hashlib.sha256(libraries[abi].read_bytes()).hexdigest(),
                "bytes": libraries[abi].stat().st_size,
            }
            for abi in libraries
        },
    }
    (output.parent / f"{output.stem}.manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ADDON / "bin" / TEMPLATE_NAME)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    manifest = build(args.output)
    print(f"Template: {args.output} ({args.output.stat().st_size:,} bytes)")
    for abi, info in manifest["libraries"].items():
        print(f"  {abi}: {info['bytes']:,} bytes, sha256={info['sha256']}")


if __name__ == "__main__":
    sys.exit(main())
