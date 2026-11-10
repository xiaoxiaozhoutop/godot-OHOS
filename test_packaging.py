"""Exercise the SCons packaging action with temporary fixtures, no engine build needed."""

import ast
import os
import re
import shutil
import tempfile
import unittest
import zipfile
from pathlib import Path
from types import SimpleNamespace


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT


class PackagingTest(unittest.TestCase):
    def test_packages_matching_abi_without_mutating_sources(self):
        tree = ast.parse((SOURCE / "platform/openharmony/SCsub").read_text())
        function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "generate_bundle")
        module = ast.Module(body=[function], type_ignores=[])

        with tempfile.TemporaryDirectory(dir="/tmp/opencode", prefix="test-ohos-package-") as directory:
            root = Path(directory)
            template = root / "platform/openharmony/template"
            (template / "entry").mkdir(parents=True)
            profile = template / "entry/build-profile.json5"
            profile.write_text('{"abiFilters": ["arm64-v8a"]}')
            header = root / "platform/openharmony/bridge_openharmony.h"
            header.write_text("// test bridge header\n")
            library = root / "libgodot.openharmony.template_release.x86_64.so"
            library.write_bytes(b"test x86_64 engine")
            original_files = sorted(str(p.relative_to(template)) for p in template.rglob("*"))

            def node(path):
                return SimpleNamespace(abspath=str(root / path.removeprefix("#")))

            namespace = {
                "os": os, "shutil": shutil, "tempfile": tempfile, "re": re,
                "Dir": node, "File": node, "lib_arch_dir": "x86_64",
            }
            exec(compile(module, "SCsub", "exec"), namespace)
            output = root / "openharmony_release_x86_64.zip"
            namespace["generate_bundle"]([output], [library], {})

            with zipfile.ZipFile(output) as archive:
                self.assertEqual(archive.read("entry/libs/x86_64/libgodot.so"), library.read_bytes())
                self.assertEqual(archive.read("entry/src/main/cpp/include/bridge_openharmony.h"), header.read_bytes())
                self.assertIn('"abiFilters": ["x86_64"]', archive.read("entry/build-profile.json5").decode())
            self.assertEqual(profile.read_text(), '{"abiFilters": ["arm64-v8a"]}')
            self.assertEqual(original_files, sorted(str(p.relative_to(template)) for p in template.rglob("*")))
            self.assertTrue(library.exists())


if __name__ == "__main__":
    unittest.main()
