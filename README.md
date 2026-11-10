# Godot for OpenHarmony / HarmonyOS

[中文](README-ZH.md) | English

A community port of **Godot 4.7.2** with ARM64 and x86_64 export templates and a GDScript editor export addon. This repository contains the engine changes, OpenHarmony project skeleton, addon, build scripts and tests in one place.

## Status

- Engine baseline: official `4.7.2-stable`, commit `ed1daf0bf001b61586d9930840f2f1394092c079`.
- Platform reference: [`kdada/godot`](https://github.com/kdada/godot), `openharmony`, commit `1de71ce53007388bc229472374235169dc5db950`.
- Builds `arm64` (HAP ABI `arm64-v8a`) and `x86_64`. One addon can export either architecture or both.
- Vulkan and OpenGL ES 3 backends. Vulkan context initialization can fall back to GLES when allowed by project settings.
- Uses the official Godot 4.7.2 desktop editor with the included addon; no custom desktop editor build is required.
- Release templates only in the packaged addon. ARM32 and C# / Mono are not supported. GDExtensions require matching OHOS binaries.

ARM64 phone Vulkan startup and landscape layout have been tested. The custom x86_64 QEMU image has rendered using GLES 3.2 Mesa virgl; it currently has no Vulkan ICD and is not configured for Venus. A separate DRM atomic presentation failure has also caused a black QEMU window despite valid system screenshots. These limitations remain unresolved; startup tests do not certify all input, audio or lifecycle behavior.

## Build and package

On Linux, install Python 3 with venv support, `readelf`, an OpenHarmony native SDK, and the matching official Godot editor for export tests. HAP builds also need a configured DevEco Command Line Tools environment.

```bash
git clone https://github.com/xiaoxiaozhoutop/godot-OHOS.git
cd godot-OHOS
python3 -m venv .venv
.venv/bin/pip install scons==4.11.1
export OPENHARMONY_SDK_PATH=/path/to/command-line-tools/sdk/default/openharmony

bash build-x86_64.sh vulkan=yes opengl3=yes
bash build-arm64.sh vulkan=yes opengl3=yes
python3 build_dual_template.py
python3 package_addon.py
```

Build architectures sequentially to respect the memory budget. `build_jobs.py` selects parallelism from available memory and CPU count; override with `JOBS=4` or `GODOT_BUILD_JOBS=4`. `SCONS=/absolute/path/to/scons` can select an existing SCons installation. The SDK path must contain `native/`.

Outputs:

```text
bin/libgodot.openharmony.template_release.{arm64,x86_64}.so
plugin/addons/godot-ohos/bin/openharmony_release_dual.zip
dist/godot-ohos-4.7.2-arm64-x86_64.zip
dist/godot-ohos-4.7.2-arm64-x86_64.zip.sha256
```

Compiled libraries and archives are not committed. Build them locally; ready-to-install addon archives can be distributed separately as release assets.

## Export a game

Extract the addon archive into your game's `addons/` directory, enable **godot-ohos**, and add an **OpenHarmony** export preset. Select the bundle name, orientation, SDK settings and architecture.

```bash
godot --headless --path /path/to/game \
  --export-release "OpenHarmony" /path/to/output/my_game
cd /path/to/output/my_game
export DEVECO_CLI_CLT_PATH=/path/to/command-line-tools
devecocli build --modules entry --build-mode release
```

The addon generates a project, not a signed HAP. SCons builds `libgodot.so`; CMake/hvigor builds the matching N-API `libentry.so` in the exported project. Configure signing for your target before installing. Existing JSON5 signing settings are preserved on re-export. Do not mix this port's native libraries with GodotHub's older bridge ABI.

## Tests

```bash
.venv/bin/python -m unittest -v test_toolchain test_packaging
python3 verify_ohos.py plugin/addons/godot-ohos/bin/openharmony_release_dual.zip
godot --headless --editor --path plugin --import
godot --headless --editor --path plugin --script res://test_export.gd
```

The Debug-export rejection is an expected negative test. Check the logged template path and perform separate device rendering, input, storage and lifecycle tests. Static ELF checks cannot prove runtime support.

## Maintenance and licensing

- [Detailed porting and upgrade guide (Chinese)](PORTING-GUIDE-ZH.md)
- [Quick build notes (Chinese)](README-build.md)
- [Agent working instructions](AGENTS.md)
- [Addon usage](plugin/addons/godot-ohos/README.md)
- [Original upstream README](README.upstream.md)

Godot is MIT-licensed; see [LICENSE.txt](LICENSE.txt) and [COPYRIGHT.txt](COPYRIGHT.txt) for engine and third-party notices. This is a community port, not an official Godot or GodotHub release.
