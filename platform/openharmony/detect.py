import os
import sys
from typing import TYPE_CHECKING

from methods import print_error
from platform_methods import validate_arch

if TYPE_CHECKING:
    from SCons.Script.SConscript import SConsEnvironment


def get_name():
    return "OpenHarmony"


def can_build():
    return True


def get_tools(env: "SConsEnvironment"):
    return ["clang", "clang++", "as", "ar", "link"]


def get_opts():
    from SCons.Variables import BoolVariable

    return [
        ("OPENHARMONY_SDK_PATH", "Path to the OpenHarmony SDK", os.environ.get("OPENHARMONY_SDK_PATH", "")),
        BoolVariable("generate_bundle", "Generate an OpenHarmony project template", False),
    ]


def get_doc_classes():
    return ["EditorExportPlatformOpenHarmony"]


def get_doc_path():
    return "doc_classes"


def get_flags():
    return {
        "arch": "arm64",
        "target": "template_debug",
        "builtin_pcre2_with_jit": False,
        "supported": [],
    }


def configure(env: "SConsEnvironment"):
    sdk_root = os.path.abspath(env["OPENHARMONY_SDK_PATH"])
    compiler_path = os.path.join(sdk_root, "native", "llvm", "bin")
    executable_suffix = ".exe" if sys.platform == "win32" else ""
    if not os.path.isfile(os.path.join(compiler_path, "clang" + executable_suffix)):
        print_error("OpenHarmony SDK not found. Set OPENHARMONY_SDK_PATH to the directory containing native/.")
        sys.exit(255)

    validate_arch(env["arch"], get_name(), ["arm64", "x86_64"])
    if env.editor_build:
        print_error("This port currently builds export templates only, not the editor.")
        sys.exit(255)
    if not env["vulkan"] and not env["opengl3"]:
        print_error("This OpenHarmony port requires vulkan=yes and/or opengl3=yes.")
        sys.exit(255)

    env["ENV"]["PATH"] = compiler_path + os.pathsep + env["ENV"]["PATH"]
    for variable, executable in {
        "CC": "clang",
        "CXX": "clang++",
        "AS": "clang",
        "AR": "llvm-ar",
        "RANLIB": "llvm-ranlib",
    }.items():
        env[variable] = os.path.join(compiler_path, executable + executable_suffix)
    env["LINK"] = env["CXX"]
    env["SHLINK"] = env["CXX"]
    env["SHLIBSUFFIX"] = ".so"

    target_triple = "x86_64-linux-ohos" if env["arch"] == "x86_64" else "aarch64-linux-ohos"
    target_flags = [f"--target={target_triple}", f"--sysroot={sdk_root}/native/sysroot"]
    env.Append(CCFLAGS=target_flags + ["-fPIC", "-ffunction-sections", "-fdata-sections", "-fstack-protector-strong"])
    env.Append(ASFLAGS=target_flags + ["-c"])
    env.Append(
        LINKFLAGS=target_flags
        + [
            "-fuse-ld=lld",
            "-Wl,--gc-sections",
            "-Wl,--no-undefined",
            "-Wl,-z,now",
            "-Wl,--build-id",
            "-Wl,-soname,libgodot.so",
        ]
    )
    env.Prepend(CPPPATH=["#platform/openharmony"])
    env.Append(
        CPPDEFINES=[
            "OPENHARMONY_ENABLED",
            "UNIX_ENABLED",
            "__OPEN_HARMONY__",
            "OHOS_PLATFORM",
            "MBEDTLS_NO_UDBL_DIVISION",
        ]
    )
    if env["vulkan"]:
        env.Append(CPPDEFINES=["VK_USE_PLATFORM_OHOS", "VULKAN_ENABLED", "RD_ENABLED"])
        # Volk's reduced platform-header list does not include OHOS yet.
        env.Append(CPPDEFINES=[("VOLK_VULKAN_H_PATH", '\\"vulkan/vulkan.h\\"')])
    if env["opengl3"]:
        env.Append(CPPDEFINES=["GLES3_ENABLED", "EGL_ENABLED", "EGL_STATIC"])
    env.Append(
        LIBS=[
            "hilog_ndk.z",
            "ace_ndk.z",
            "ace_napi.z",
            "rawfile.z",
            "native_window",
            "native_vsync",
            "ohaudio",
            "ohinputmethod",
            "native_display_manager",
            "native_window_manager",
            "native_drawing",
            "udmf",
            "pasteboard",
            "dl",
            "m",
            "pthread",
        ]
    )
    if env["vulkan"] and not env["use_volk"]:
        env.Append(LIBS=["vulkan"])
    if env["opengl3"]:
        env.Append(LIBS=["EGL", "GLESv3"])

    if env["lto"] == "auto":
        env["lto"] = "none"
    if env["lto"] != "none":
        flag = "-flto=thin" if env["lto"] == "thin" else "-flto"
        env.Append(CCFLAGS=[flag], LINKFLAGS=[flag])
