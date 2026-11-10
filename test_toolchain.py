"""Configuration checks for OHOS SDK selection and cross-compiler flags."""

import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT
sys.path.insert(0, str(SOURCE))
spec = importlib.util.spec_from_file_location("ohos_detect", SOURCE / "platform/openharmony/detect.py")
detect = importlib.util.module_from_spec(spec)
spec.loader.exec_module(detect)


class Environment(dict):
    editor_build = False

    def Append(self, **kwargs):
        for key, values in kwargs.items():
            self.setdefault(key, []).extend(values)

    def Prepend(self, **kwargs):
        for key, values in kwargs.items():
            self[key] = values + self.get(key, [])


class ToolchainTest(unittest.TestCase):
    def test_sdk_path_and_architecture(self):
        with tempfile.TemporaryDirectory(prefix="ohos-sdk-", dir="/tmp/opencode") as directory:
            # Exercise spaces in the SDK path too.
            sdk = Path(directory) / "SDK with spaces"
            compiler = sdk / "native/llvm/bin"
            compiler.mkdir(parents=True)
            (compiler / "clang").touch()
            for arch, triple in [("x86_64", "x86_64-linux-ohos"), ("arm64", "aarch64-linux-ohos")]:
                for opengl3 in (False, True):
                    with self.subTest(arch=arch, opengl3=opengl3):
                        env = Environment(
                            OPENHARMONY_SDK_PATH=str(sdk), arch=arch,
                            opengl3=opengl3, vulkan=True, use_volk=True,
                            lto="auto", ENV={"PATH": "/usr/bin"},
                        )
                        detect.configure(env)
                        self.assertEqual(env["CC"], str(compiler / "clang"))
                        self.assertEqual(env["LINK"], str(compiler / "clang++"))
                        self.assertEqual(env["ENV"]["PATH"], str(compiler) + os.pathsep + "/usr/bin")
                        self.assertIn(f"--target={triple}", env["CCFLAGS"])
                        self.assertIn(f"--sysroot={sdk}/native/sysroot", env["LINKFLAGS"])
                        self.assertIn("-Wl,--no-undefined", env["LINKFLAGS"])
                        self.assertIn("VK_USE_PLATFORM_OHOS", env["CPPDEFINES"])
                        self.assertIn("OHOS_PLATFORM", env["CPPDEFINES"])
                        if opengl3:
                            self.assertIn("GLES3_ENABLED", env["CPPDEFINES"])
                            self.assertIn("EGL_ENABLED", env["CPPDEFINES"])
                            self.assertIn("EGL_STATIC", env["CPPDEFINES"])
                            self.assertIn("EGL", env["LIBS"])
                            self.assertIn("GLESv3", env["LIBS"])
                        else:
                            self.assertNotIn("GLES3_ENABLED", env["CPPDEFINES"])
                        self.assertEqual(env["lto"], "none")
                        self.assertNotIn("-fobjc-arc", env["CCFLAGS"])

    def test_rejects_missing_sdk(self):
        with tempfile.TemporaryDirectory(prefix="ohos-empty-sdk-", dir="/tmp/opencode") as directory:
            with self.assertRaises(SystemExit):
                detect.configure(Environment(OPENHARMONY_SDK_PATH=directory))


if __name__ == "__main__":
    unittest.main()
