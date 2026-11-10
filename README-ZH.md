# Godot OpenHarmony / HarmonyOS 移植

中文 | [English](README.md)

基于 **Godot 4.7.2** 的社区移植，支持 ARM64、x86_64 导出模板及 GDScript 编辑器导出插件。本仓库包含引擎修改、鸿蒙工程骨架、插件、构建脚本和测试，可独立构建，不再依赖上一级工作区的脚本。

## 支持情况

- 官方基线：`4.7.2-stable`，提交 `ed1daf0bf001b61586d9930840f2f1394092c079`。
- 平台参考：[`kdada/godot`](https://github.com/kdada/godot) 的 `openharmony` 分支，提交 `1de71ce53007388bc229472374235169dc5db950`。
- 支持 SCons `arm64`（HAP ABI 为 `arm64-v8a`）和 `x86_64`；同一插件可导出单架构或双架构。
- 支持 Vulkan 与 GLES 3；项目设置允许时，Vulkan context 初始化失败可回退 GLES。
- 使用官方 Godot 4.7.2 桌面编辑器加载插件，无需编译定制桌面编辑器。
- 插件只分发 Release 模板，不支持 ARM32、C# / Mono；GDExtension 需自行提供对应 OHOS 二进制。

ARM64 手机已有 Vulkan 启动与横屏布局验证记录；自定义 x86_64 QEMU 镜像已有 GLES 3.2 Mesa virgl 渲染记录。该镜像目前缺少 Vulkan ICD，也未启用 Venus；另有 DRM atomic 提交失败导致“系统截图有内容、QEMU 窗口黑屏”的问题，尚未修复。启动通过不代表音频、完整输入及生命周期均已验收。

## 编译与打包

Linux 环境需 Python 3/venv、`readelf`、OpenHarmony native SDK；导出测试需匹配的官方 Godot 编辑器。构建 HAP 还需配置 DevEco Command Line Tools。

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

建议顺序编译两个架构。`build_jobs.py` 按可用内存与 CPU 数选择并发，可用 `JOBS=4` 或 `GODOT_BUILD_JOBS=4` 覆盖；用 `SCONS=/absolute/path/to/scons` 选择现有 SCons。SDK 路径必须包含 `native/`。

产物：

```text
bin/libgodot.openharmony.template_release.{arm64,x86_64}.so
plugin/addons/godot-ohos/bin/openharmony_release_dual.zip
dist/godot-ohos-4.7.2-arm64-x86_64.zip
dist/godot-ohos-4.7.2-arm64-x86_64.zip.sha256
```

库、模板 ZIP 和分发 ZIP 不进入源码提交，应本地构建；完整插件包可作为独立 Release 附件分发。

## 导出游戏

将插件包解压到游戏的 `addons/`，启用 **godot-ohos**，添加 **OpenHarmony** 导出预设并设置包名、方向、SDK 和架构。

```bash
godot --headless --path /path/to/game \
  --export-release "OpenHarmony" /path/to/output/my_game
cd /path/to/output/my_game
export DEVECO_CLI_CLT_PATH=/path/to/command-line-tools
devecocli build --modules entry --build-mode release
```

插件生成工程，不直接生成已签名 HAP。SCons 编译 `libgodot.so`；导出工程通过 CMake/hvigor 编译匹配的 N-API `libentry.so`。安装前需配置目标设备所需签名；重复导出保留现有 JSON5 签名配置。不要混用 GodotHub 旧版桥接库。

## 测试

```bash
.venv/bin/python -m unittest -v test_toolchain test_packaging
python3 verify_ohos.py plugin/addons/godot-ohos/bin/openharmony_release_dual.zip
godot --headless --editor --path plugin --import
godot --headless --editor --path plugin --script res://test_export.gd
```

Debug 导出拒绝属于预期负例。核对日志中的模板路径；渲染、输入、存储和生命周期仍需设备验证，不能用 ELF 静态检查替代。

## 维护与许可

- [完整移植与版本升级教程](PORTING-GUIDE-ZH.md)
- [快速构建说明](README-build.md)
- [代理工作约定](AGENTS.md)
- [插件使用说明](plugin/addons/godot-ohos/README-ZH.md)
- [保留的官方 README](README.upstream.md)

Godot 使用 MIT 许可；引擎及第三方许可见 [LICENSE.txt](LICENSE.txt)、[COPYRIGHT.txt](COPYRIGHT.txt)。本项目不是 Godot 或 GodotHub 官方发行版。
