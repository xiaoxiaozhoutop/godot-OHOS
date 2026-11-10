#!/usr/bin/env python3
"""Check OHOS ARM64/x86_64 engine libraries or project-template ZIPs without running them."""

import argparse
import hashlib
import re
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path


MACHINES = {"x86_64": 62, "arm64-v8a": 183}


def verify_library(path: Path, abi: str | None = None) -> None:
    data = path.read_bytes()
    if len(data) < 64 or data[:6] != b"\x7fELF\x02\x01":
        raise ValueError("Expected a little-endian 64-bit ELF library")
    elf_type, machine = struct.unpack_from("<HH", data, 16)
    if elf_type != 3 or machine not in MACHINES.values():
        raise ValueError(f"Expected ARM64/x86_64 shared library, got type={elf_type}, machine={machine}")
    if abi and machine != MACHINES[abi]:
        raise ValueError(f"ELF machine does not match ABI directory {abi}: {machine}")
    architecture = next(name for name, value in MACHINES.items() if value == machine)

    dynamic = subprocess.check_output(["readelf", "-dW", str(path)], text=True)
    if "[libgodot.so]" not in dynamic:
        raise ValueError("Missing expected SONAME libgodot.so")
    for host_library in ("libc.so.6", "libstdc++.so.6", "libgcc_s.so.1", "ld-linux-x86-64.so.2"):
        if f"[{host_library}]" in dynamic:
            raise ValueError(f"Unexpected Linux host dependency: {host_library}")

    symbols = subprocess.check_output(["readelf", "--dyn-syms", "-W", str(path)], text=True)
    exported = {
        fields[-1]
        for line in symbols.splitlines()
        if len(fields := line.split()) >= 8 and fields[6] != "UND" and fields[4] == "GLOBAL"
    }
    required = {"godot_init", "godot_touch", "godot_mouse", "godot_key", "godot_resize", "godot_window_event"}
    if missing := required - exported:
        raise ValueError(f"Missing bridge exports: {sorted(missing)}")

    print(f"ELF: {architecture} shared library, {len(data):,} bytes")
    print(f"SHA256: {hashlib.sha256(data).hexdigest()}")
    print("Bridge exports: OK")
    print("Dependencies:")
    for line in dynamic.splitlines():
        if "(NEEDED)" in line:
            print(" ", line.strip())


def verify_template(path: Path) -> None:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        libraries = {name for name in names if name.endswith(".so")}
        abis = [abi for abi in MACHINES if f"entry/libs/{abi}/libgodot.so" in libraries]
        expected = {f"entry/libs/{abi}/libgodot.so" for abi in abis}
        if not expected or libraries != expected:
            raise ValueError(f"Unexpected native libraries in template: {sorted(libraries)}")
        required = [
            "entry/src/main/cpp/include/bridge_openharmony.h",
            "entry/src/main/cpp/napi_init.cpp",
            "entry/src/main/cpp/CMakeLists.txt",
            "entry/src/main/ets/pages/Index.ets",
        ]
        for name in required:
            if name not in names:
                raise ValueError(f"Missing template file: {name}")
        profile = archive.read("entry/build-profile.json5").decode()
        filters = re.search(r'"abiFilters"\s*:\s*\[([^\]]*)\]', profile)
        if not filters or set(re.findall(r'"([^"]+)"', filters[1])) != set(abis):
            raise ValueError("Template abiFilters does not match packaged architectures")
        if error := archive.testzip():
            raise ValueError(f"ZIP CRC check failed: {error}")
        with tempfile.TemporaryDirectory(prefix="verify-ohos-", dir="/tmp/opencode") as directory:
            for abi in abis:
                library = Path(directory) / f"{abi}.so"
                library.write_bytes(archive.read(f"entry/libs/{abi}/libgodot.so"))
                verify_library(library, abi)
    print("Template structure and ZIP CRC: OK")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    args = parser.parse_args()
    if args.artifact.suffix == ".zip":
        verify_template(args.artifact)
    else:
        verify_library(args.artifact)
    print("Static checks passed. Device/emulator execution has NOT been verified.")


if __name__ == "__main__":
    main()
