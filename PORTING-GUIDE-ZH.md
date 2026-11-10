# Godot OpenHarmony 移植、编译与版本升级教程

本文记录 Godot 4.7.2 移植实现与构建流程，供重建当前版本及移植后续版本使用。构建工具与插件现已整合进引擎仓库，所有相对路径以本仓库根目录为准；本机目录是 `/home/zhou/Documents/godot/godot-4.7.2-ohos/`。

## 1. 基线与当前状态

- 官方引擎：`https://github.com/godotengine/godot`，标签 `4.7.2-stable`，提交 `ed1daf0bf001b61586d9930840f2f1394092c079`。
- 平台参考：`https://github.com/kdada/godot`，`openharmony` 分支，参考提交 `1de71ce53007388bc229472374235169dc5db950`。
- 当前源码位于本仓库根目录，移植分支名为 `ohos-x86_64-4.7.2`。源码是否已提交及推送应以 Git 状态为准。
- 编辑器：官方 `4.7.2.stable.official.ed1daf0bf`，通过 GDScript 编辑器插件提供 OpenHarmony 导出入口，不需要重编桌面编辑器。
- 目标架构：SCons 的 `arm64` 对应 HAP 的 `arm64-v8a`；`x86_64` 两处同名。
- 渲染：编译支持 Vulkan 和 GLES 3。当前导出插件只分发 Release 模板，不支持 ARM32、C# / Mono。

已完成双架构构建、模板校验、工具链/打包单元测试、无头导出测试及设备安装启动。ARM64 手机有 Vulkan 渲染和横屏布局的验证记录；x86_64 模拟器有 GLES 3.2 Mesa virgl 渲染、点击、调整尺寸和 `user://` 写入记录。它们不等于完整的音频、输入、生命周期或全渲染特性认证。

**尚未解决：**当前 QEMU OpenHarmony 镜像没有 Vulkan ICD，QEMU 也未启用 Venus/blob 通道，因此仍回退 GLES。另有 QEMU DRM atomic 提交失败造成“系统截图有内容、宿主窗口黑屏”的记录。不能把离屏截图当作显示输出已经正常的证据。

## 2. 工程结构与产物关系

```text
godot-OHOS/                       # 本仓库，含完整官方引擎源码
├── platform/openharmony/
│   ├── detect.py                # 交叉工具链配置
│   ├── SCsub                    # libgodot.so 和单架构工程模板打包
│   ├── bridge_openharmony.*     # C ABI 与主循环/输入桥接
│   └── template/                # ArkTS、N-API、CMake 和资源模板
├── bin/                         # SCons 生成的引擎库，不提交
├── plugin/                     # 可用官方 Godot 打开的插件测试工程
│   ├── addons/godot-ohos/      # 编辑器导出插件源码与双架构模板
│   └── test_export.gd
├── build-x86_64.sh
├── build-arm64.sh
├── build_jobs.py
├── build_dual_template.py
├── package_addon.py
├── verify_ohos.py
└── dist/                       # 最终插件 ZIP 和 SHA256
```

构建分为三层：

1. **SCons 编译引擎**：生成各架构的 `libgodot.openharmony.template_release.<arch>.so`，模板内重命名为 `libgodot.so`。
2. **Python 合并和打包插件**：把两个引擎库及鸿蒙工程骨架放进 `openharmony_release_dual.zip`，再连同 GDScript 导出插件打成分发 ZIP。GDScript 插件本身没有独立的 C++ 编译步骤。
3. **导出后用 hvigor 构建 HAP**：插件生成鸿蒙工程及 `template.pck`；鸿蒙工程的 CMake 为所选架构编译 N-API 桥接库 `libentry.so`，随后打包、签名。

`libgodot.so`、`bridge_openharmony.h`、`napi_init.cpp` 和 ArkTS 类型声明必须来自匹配的一套源码。不要混用 GodotHub 原有的 `libgodot_4_7.so` / `libentry_4_7.so`，它们与本移植的桥接 ABI 不兼容。

## 3. 引擎修改清单

### 3.1 新增平台层 `platform/openharmony/`

后续移植以该目录为主体，但每次都需对照目标版本的引擎接口适配，不能只复制后忽略编译警告。

| 位置 | 本次实现及升级检查重点 |
|---|---|
| `detect.py` | Linux/Windows 工具名后缀、SDK 路径检查、两种架构校验；使用 SDK clang、LLD、sysroot；配置平台宏、系统库、Vulkan/GLES；拒绝编译编辑器目标 |
| `SCsub` | 生成共享引擎库；用临时 staging 打包单架构鸿蒙工程，避免将生成物写回源模板；同步桥接头文件和 `abiFilters` |
| `os_openharmony.h`、`os_openharmory.cpp` | OS/窗口信息、日志、字体和系统接口、应用沙箱路径。注意 `.cpp` 文件名当前拼作 `openharmory`，搜索时不要漏掉 |
| `bridge_openharmony.*` | `godot_init`、触摸、鼠标、键盘、尺寸和窗口事件；解析 rawfile `_cl_` 启动参数；ArkUI 线程到 VSync 线程的主线程交接 |
| `display_server_openharmony.*` | Vulkan RenderingDevice 与 EGL/GLES 路径、窗口尺寸、输入分发；Vulkan context 初始化失败时按项目设置回退 GLES |
| `rendering_context_driver_vulkan_openharmony.*` | 通过 `VK_OHOS_surface` 和 `vkCreateSurfaceOHOS` 创建窗口表面 |
| `egl_manager_openharmony.*`、`platform_gl.h`、`platform_egl.h` | OHNativeWindow 与 EGL/GLES 接入 |
| 文件/目录、音频、输入法等平台文件 | rawfile 资源访问和 OHOS 系统接口；编译通过不能代替各项设备功能测试 |
| `template/entry/src/main/ets/pages/Index.ets` | XComponent、权限、输入和生命周期桥接；初始化前传入 `filesDir/cacheDir/tempDir` |
| `template/entry/src/main/cpp/napi_init.cpp` | N-API 参数转换；等待有效的 native window 和非零尺寸再启动，避免过早用无效表面初始化渲染 |

启动过程先运行 `Main::setup(..., false)`，释放原线程的主线程身份，再在 VSync 回调运行 `Main::setup2(false)`、启动画面和主循环。新版本若调整 `Main`、线程安全标记或渲染线程初始化顺序，优先检查这条链路。

### 3.2 平台目录之外的公共补丁

相对官方基线，当前有以下 10 个被跟踪文件的修改。迁移时逐项确认新上游是否已解决同类问题，不要盲目重新覆盖。

| 文件 | 修改目的 |
|---|---|
| `core/config/project_settings.cpp` | 将 OpenHarmony 加入从应用资源目录查找 PCK 的分支，使 rawfile 中的游戏包可被加载 |
| `drivers/egl/egl_manager.cpp` | OHOS 的 EGL display/window surface 创建回退；通过 `eglGetProcAddress` 获取 blob cache 扩展；处理静态 EGL 符号和可空平台扩展名 |
| `drivers/gles3/storage/config.cpp`、`config.h` | 将 OHOS 纳入 GLES 扩展函数与能力检测路径 |
| `drivers/gles3/storage/render_scene_buffers_gles3.cpp` | OHOS 使用 GLES 的 MSAA、多视图、纹理存储和帧缓冲处理分支 |
| `drivers/gles3/storage/texture_storage.cpp` | 外部 OES 纹理/EGLImage 的 OHOS 路径 |
| `drivers/vulkan/rendering_device_driver_vulkan.cpp` | OHOS 在支持时选择 `IDENTITY` preTransform，避免 XComponent 尺寸与 Vulkan 旋转叠加；尺寸交换也使用选定的 transform |
| `thirdparty/embree/common/sys/sysinfo.cpp` | OHOS 使用 `sysconf(_SC_NPROCESSORS_ONLN)` 查询核心数 |
| `thirdparty/embree/common/sys/thread.cpp` | 适配 OHOS 可用的线程/亲和性接口，避免使用未实现的 `pthread_cancel` 路径 |
| `thirdparty/zstd/common/portability_macros.h` | OHOS 禁用该处不兼容的汇编支持判断 |

Vulkan 的 `IDENTITY` 改动限定在 `OPENHARMONY_ENABLED`。后续若上游调整交换链坐标或旋转处理，需要重新检查尺寸、preTransform 与 present 路径是否一致，并用横竖屏实际测试。

### 3.3 `user://` 与缓存

ArkTS 将应用上下文目录传给 `setAppDirectories`，N-API 经 C ABI 调用 `OS_OpenHarmony::set_app_directories`。OS 的 data/config/user-data 路径取应用 `filesDir`，cache 和 temp 分别取对应沙箱目录。后续版本不要恢复为仅依赖硬编码路径，也不要让图形缓存初始化早于目录注入。

### 3.4 编辑器插件修改

`plugin/addons/godot-ohos/` 提供导出预设、参数转换和工程生成：

- 同一双架构模板支持选择 `arm64-v8a`、`x86_64` 或两者；裁剪 `entry/libs/` 时同步 `abiFilters`。
- 根据项目移动端渲染设置写入 rawfile `_cl_`。`gl_compatibility` 对应 `opengl3`，其余支持的 RD 渲染方式使用 `vulkan`。
- 重新导出时保留已有 JSON5 `signingConfigs` 和产品引用，兼容不带引号的 JSON5 键；不能用 JSON 解析器强行处理所有 JSON5。
- 明确拒绝 Debug 导出，不以 Release 原生库冒充 Debug 模板。
- 插件只生成工程，不负责构建、签名或安装 HAP。

平台目录中还保留了原生 `export/` 实现，但本工作区使用的是官方桌面编辑器加 GDScript 插件；不要把两种导出实现误认为已同时验证。

## 4. 重建当前版本

### 4.1 环境准备

需要 Python 3、venv、SCons、`readelf`、OpenHarmony native SDK，以及用于导出测试的官方 Godot 4.7.2。构建 HAP 还需要可用的 DevEco Command Line Tools、Java、ohpm 和 hvigor 环境。

```bash
cd /path/to/godot-OHOS
python3 -m venv .venv
.venv/bin/pip install scons==4.11.1

export OPENHARMONY_SDK_PATH=/home/zhou/command-line-tools/sdk/default/openharmony
export DEVECO_CLI_CLT_PATH=/home/zhou/command-line-tools
export TMPDIR=/tmp/opencode
mkdir -p "$TMPDIR"

godot --version
test -x "$OPENHARMONY_SDK_PATH/native/llvm/bin/clang"
test -d "$OPENHARMONY_SDK_PATH/native/sysroot"
```

`OPENHARMONY_SDK_PATH` 指向含 `native/` 的目录；`DEVECO_CLI_CLT_PATH` 指向 Command Line Tools 根目录，两者不可互换。

### 4.2 编译两个架构

```bash
cd /path/to/godot-OHOS
bash build-x86_64.sh vulkan=yes opengl3=yes
bash build-arm64.sh vulkan=yes opengl3=yes
```

建议顺序编译两个架构，避免同时构建超过内存预算。脚本默认使用 `template_release`、`debug_symbols=no`、`lto=none`、`generate_bundle=yes`。它调用的核心命令等价于：

```bash
.venv/bin/scons platform=openharmony arch=x86_64 \
  target=template_release OPENHARMONY_SDK_PATH="$OPENHARMONY_SDK_PATH" \
  vulkan=yes opengl3=yes debug_symbols=no lto=none generate_bundle=yes -j4
```

目标 triple 是 `x86_64-linux-ohos` 或 `aarch64-linux-ohos`，不能使用宿主 Linux 编译器生成的 glibc 动态库替代。

默认并行度取 CPU 核心数、可用内存预算和上限的最小值：单任务估算 1200 MB，给系统保留 1500 MB，上限 8。覆盖方式：

```bash
JOBS=4 bash build-x86_64.sh vulkan=yes opengl3=yes
GODOT_BUILD_JOBS=4 bash build-arm64.sh vulkan=yes opengl3=yes
GODOT_BUILD_MAX_JOBS=6 GODOT_BUILD_JOB_MEMORY_MB=1500 bash build-x86_64.sh
```

`TARGET=template_debug` 可以请求编译引擎 Debug 目标，但当前双架构合并脚本和插件只消费 Release 库，不能因此宣称插件支持 Debug 导出。

编译输出包括：

```text
bin/libgodot.openharmony.template_release.arm64.so
bin/libgodot.openharmony.template_release.x86_64.so
bin/openharmony_release_arm64-v8a.zip
bin/openharmony_release_x86_64.zip
```

### 4.3 合并模板、打包插件

以下命令在仓库根目录运行；合并脚本按自身位置定位源码，不再依赖父目录布局。

```bash
cd /path/to/godot-OHOS
python3 build_dual_template.py
python3 package_addon.py
```

结果：

- `plugin/addons/godot-ohos/bin/openharmony_release_dual.zip`
- `plugin/addons/godot-ohos/bin/openharmony_release_dual.manifest.json`
- `dist/godot-ohos-4.7.2-arm64-x86_64.zip`
- `dist/godot-ohos-4.7.2-arm64-x86_64.zip.sha256`

manifest 记录库哈希和大小，`renderer` 为 `vulkan-and-opengl-es3`。每次重新打包都应重新读取哈希，不沿用历史发布包的 SHA256。生成库、模板和分发 ZIP 不纳入源码提交。

### 4.4 校验与无头导出测试

```bash
cd /path/to/godot-OHOS
.venv/bin/python -m unittest -v test_toolchain test_packaging
python3 verify_ohos.py plugin/addons/godot-ohos/bin/openharmony_release_dual.zip
godot --headless --editor --path plugin --import
godot --headless --editor --path plugin --script res://test_export.gd
```

静态校验检查 ELF64 架构、SONAME、桥接导出符号、误链接宿主 glibc 的依赖，以及模板结构和 CRC。`verify_ohos.py` 末尾的“运行时未验证”只描述该工具的能力，不会自动读取设备验证历史。

`test_export.gd` 检查双架构和单架构裁剪、Debug 导出拒绝、签名保留及渲染启动参数。其输出在测试工程 `plugin/build/ohos/` 下，测试时不要改成真实游戏的生产导出目录。

运行时还要核对日志中的 `Template:` 路径。模板目录来自全局编辑器设置 `export/harmony/export_preset`，可能残留其他项目的路径；测试脚本现会临时选择本仓库模板，并在正常完成时恢复原值。实际游戏导出也应核对该设置。脚本测试中的 Debug 拒绝报错属于预期负例；测试运行还出现过编辑器快速退出时的 RID/ObjectDB 泄漏警告，未在本次整合任务中修复。

## 5. 安装插件、导出游戏并构建 HAP

1. 备份游戏中旧的 `addons/godot-ohos/`。
2. 将分发 ZIP 解压到游戏的 `addons/`，最终得到 `addons/godot-ohos/plugin.cfg`，避免额外嵌套一层目录。
3. 用匹配版本的官方 Godot 打开项目，启用插件，添加 OpenHarmony 导出预设。
4. 设置 bundle name、SDK、屏幕方向和目标架构；首次先用最小场景测试。

```bash
godot --headless --path /path/to/game \
  --export-release "OpenHarmony" /path/to/game/build/ohos/my_game

cd /path/to/game/build/ohos/my_game
export DEVECO_CLI_CLT_PATH=/home/zhou/command-line-tools
devecocli build --modules entry --build-mode release
```

预设名应与 `export_presets.cfg` 一致。导出的是工程目录，不是 HAP 文件。产物通常位于 `entry/build/default/outputs/default/`，包括 `entry-default-unsigned.hap`；配置有效签名后会有 `entry-default-signed.hap`。

真机签名流程：

```bash
devecocli device list
devecocli auth login
devecocli signature generate
devecocli run --device <真机序列号> --module entry --build-mode release
```

签名生成会更新工程配置及本机签名材料。不要把证书、p12、p7b、密码或个人设备 UDID 纳入插件发布包。更新插件后需重新导出并构建 HAP，不能只更新插件 ZIP 后直接安装旧 HAP。

## 6. 设备验证与已知问题

### 6.1 最小验证清单

- 启动后查看日志中的 Godot 版本、实际渲染后端、GPU 和初始化尺寸。
- 真机检查横竖屏、宽高比、全屏边缘和触摸坐标是否一致。
- 模拟器检查鼠标移动、点击、窗口缩放；事件接收与鼠标位置轮询分别验证。
- 写入并读回 `user://` 文件，确认 shader cache 不再因目录权限失败。
- 检查前后台切换、恢复、退出、音频和输入法，逐项记录通过/失败/未测。
- 同时观察实际设备/QEMU 窗口和系统截图，不能只确认进程存在。

```bash
devecocli log --device <序列号> \
  --bundle-name com.example.mygame --tail 200
devecocli ui screenshot --device <序列号> --path /tmp/opencode/mygame-check.png
```

截图路径需尚不存在。日志、截图和 PID 都是当次运行的证据，不应复制历史 PID 当作最新状态。

### 6.2 当前 x86_64 QEMU 的签名限制

当前自定义镜像安装正常 HarmonyOS 云签名包曾报 `9568404 delivery sign profile failed`，日志指向缺失 `/dev/code_sign`；还记录过 x86_64 code-sign 库的 `statx` 调用号问题。这是本镜像的限制，不是所有 OpenHarmony 模拟器的通用结论。

已验证的临时测试方法是复制**未签名 HAP**，只在副本中把 `module.json` 的 `app.compileSdkType` 改为 `OpenHarmony`、`minAPIVersion` 改为 `22`、`targetAPIVersion` 改为 `26`，使用 SDK 的 `OpenHarmony.p12` 签出 `release`、`os_integration` profile，再通过 hdc 安装。只修改测试副本，不覆盖真机签名配置。完整本地重签自动化脚本目前没有纳入本工作区，不能直接用 `devecocli run` 替代这一步。

最近一次重签测试产物曾保存于 `/tmp/opencode/gpz-sign-FqQ0dI/gpz-ohos-rel-signed.hap`，属于临时文件，不是稳定发布位置。重复测试应复用安全保存的同一证书，避免每次生成新证书导致 `9568332 install sign info inconsistent`。需要卸载时必须先获得确认，卸载可能清除存档。

### 6.3 Vulkan 缺 ICD 与 QEMU 黑屏

当前模拟器只有 Vulkan loader、OHOS swapchain 层，没有 ICD；启动参数为 `virtio-gpu-gl-pci`，未启用 Venus，内核报告 blob 资源关闭。宿主机支持 Vulkan，并不能让客体自动获得 Vulkan 支持。

硬件加速 Vulkan 后续需启用 QEMU Venus/blob/hostmem，并构建与 OpenHarmony ABI 匹配的 Mesa Venus ICD，再验证 OHOS surface、缓冲区共享和交换链呈现。不能直接复制 Linux glibc 驱动，也不能把强制禁止回退当成修复。

另一次黑屏诊断记录：系统合成截图有游戏内容，但 DRM 提交报告 `drmModeAtomicCommit ... errno 22`，内核提示 `Plane must cover entire CRTC`，plane 仍为 `800x600` 而请求模式为 `1252x1501`。这是显示输出链路的问题；应重新采集当前 DRM 状态，不把旧模式尺寸当成所有黑屏的原因。

当前 `DisplayServerOpenHarmony::mouse_get_position()` 还有桩实现限制；存在 `.onMouse` 事件桥接不代表所有鼠标 API 都已经实现。

## 7. 移植后续 Godot 版本

### 7.1 先保存完整移植基线

现在平台、插件与构建工具都位于同一引擎仓库。先检查差异与未跟踪文件：

```bash
git status --short
git diff --stat
git ls-files --others --exclude-standard
```

**`git diff` 不包含未跟踪文件。** 最初整合前 `platform/openharmony/` 整体未跟踪，曾有遗漏风险。迁移前检查新增文件，并把平台层、公共补丁、构建脚本和 `plugin/` 保存为提交或经过校验的完整备份。不要在尚未保存的树上直接切标签、reset 或清理文件。

建议按工具链、平台运行时、公共依赖、渲染、导出插件拆成可审查提交。若需要自动化代理提交，另行明确授权。

### 7.2 在新目录迁移

为新官方标签建立独立源码目录，保留当前可运行版本。先迁移平台目录，再按第 3.2 节重放公共补丁。重点对照新版本的：

- `platform_methods`、`detect.py`、SCons 变量和共享库输出命名；
- `OS`、`DisplayServer`、`FileAccess`、`DirAccess`、音频驱动等虚函数签名；
- `Main::setup/setup2/start` 和主线程/VSync 生命周期；
- RenderingContext/RenderingDevice 初始化、Vulkan swapchain 旋转；
- EGL/GLES 扩展能力、MSAA、多视图与外部纹理分支；
- Embree、zstd 更新是否已移除原兼容问题；
- 官方编辑器的导出插件 API、预设属性和 PCK 格式。

先编译一个架构获得接口错误，再完成另一个架构。新版本推荐继续用 Vulkan + GLES 双后端，除非有明确裁剪需求。

### 7.3 更新版本耦合处

当前脚本仍有版本标记。升级前搜索旧版本：

```bash
rg -n '4\.7\.2' \
  --glob '*.py' --glob '*.sh' --glob '*.gd' --glob '*.md' --glob '*.cfg' \
  --glob '!thirdparty/**' .
```

至少检查 `build_dual_template.py` 的 manifest 版本、`package_addon.py` 的默认文件名、插件版本说明及本文档。构建和测试路径现已相对仓库定位，不需要重命名源码目录。不要批量替换历史提交说明或整个第三方源码树。

### 7.4 重新验收再发布

按第 4.4 节运行静态与导出测试，再构建 HAP 并测试 ARM64 真机和 x86_64 模拟器。测试使用目标版本的官方编辑器，不能用旧版编辑器证明新版 PCK/导出兼容。

发布记录应包括官方 tag/commit、平台参考 commit、本地补丁 commit、SDK/工具版本、构建参数、两种库及插件包哈希、实际渲染后端、设备信息和未通过项。缺 ICD、签名或 DRM 问题应留在限制列表，不能随引擎版本号更新而默认视为解决。
