# OpenHarmony Godot 移植工作区约定

## 目标与入口

维护官方 Godot 的 OpenHarmony/HarmonyOS 导出模板和 GDScript 编辑器导出插件，支持 ARM64 与 x86_64。动手前阅读 `PORTING-GUIDE-ZH.md`，快速构建入口见 `README-build.md`。

当前基线：官方 `4.7.2-stable`，`ed1daf0bf001b61586d9930840f2f1394092c079`；平台参考 `kdada/godot` 的 `openharmony`，`1de71ce53007388bc229472374235169dc5db950`。本目录就是引擎仓库根目录，构建脚本、插件与测试均已整合；不依赖父目录工作区。

## 修改安全

- 先查看引擎的 `git status --short`、`git diff` 和未跟踪文件。已有改动可能是用户工作，不得覆盖或撤回。
- `git diff` 不包含未跟踪文件，迁移前检查 `git ls-files --others --exclude-standard`。必须保存平台目录、公共补丁、根目录脚本及 `plugin/`。
- 不自行提交、切换基线、reset、清理构建树或删除旧产物。新版本优先使用独立源码目录，保留已验证版本。
- 不直接修改 `/home/zhou/Documents/code/GodotProjectZero/`、`/home/zhou/Documents/qemu/` 或设备系统，除非当前任务需要且得到相应授权。重启模拟器、修改镜像和卸载应用前说明影响；卸载可能丢失存档。
- 签名材料、密码、p12/p7b/证书和个人 UDID 不得进入插件分发包或文档。重新导出必须保留现有 JSON5 签名配置。

## 源码与产物边界

- 引擎平台源码：`platform/openharmony/`。
- ArkTS/N-API/CMake 工程骨架：其下 `template/`，是运行时桥接的源码来源。
- 公共补丁：`core/config/project_settings.cpp`，`drivers/egl/egl_manager.cpp`，GLES3 storage 的 config、render_scene_buffers、texture_storage，Vulkan rendering_device_driver，以及 Embree sysinfo/thread、zstd portability_macros。详见教程逐文件表。
- 编辑器插件：`plugin/addons/godot-ohos/`，官方桌面编辑器加载它提供导出入口。平台下的原生 `export/` 不等同于该已验证流程。
- 引擎 `libgodot.so` 由 SCons 编译；N-API `libentry.so` 在导出后的鸿蒙工程中由 CMake/hvigor 编译；插件 GDScript 不单独编译为 `.so`。
- `bridge_openharmony.h`、引擎库、N-API 和 ArkTS 接口必须匹配。不得混入 GodotHub 的旧桥接库。
- 不手改 ZIP 内的生成文件作为永久修复。修改源模板/插件，重新构建或打包，再校验。
- `os_openharmory.cpp` 是现有文件名，勿因拼写看似错误而顺手重命名。

## 编译与打包

在仓库根目录执行：

```bash
export OPENHARMONY_SDK_PATH=/home/zhou/command-line-tools/sdk/default/openharmony
export DEVECO_CLI_CLT_PATH=/home/zhou/command-line-tools
export TMPDIR=/tmp/opencode
bash build-x86_64.sh vulkan=yes opengl3=yes
bash build-arm64.sh vulkan=yes opengl3=yes
python3 build_dual_template.py
python3 package_addon.py
```

- SCons 位于 `.venv/bin/scons`，当前安装约定 `scons==4.11.1`。
- `build_jobs.py` 按可用内存选并发；用 `JOBS` 或 `GODOT_BUILD_JOBS` 覆盖。不要仅按 CPU 核数开满，也不要默认并行构建两个架构。
- `arm64` 是 SCons 架构名，模板/HAP 路径是 `arm64-v8a`。
- 当前分发只支持 `template_release`。编出 Debug 库不代表双架构打包和插件已支持 Debug。
- 合并脚本按自身位置定位源码与默认产物；文档命令统一在仓库根运行。
- 只改插件脚本可重打插件包；改 ArkTS/N-API/工程模板至少需重合并模板、打包、导出并构建 HAP；改引擎/C ABI 需重编受影响架构并完成后续全链路。

## 必跑检查

```bash
.venv/bin/python -m unittest -v test_toolchain test_packaging
python3 verify_ohos.py plugin/addons/godot-ohos/bin/openharmony_release_dual.zip
godot --headless --editor --path plugin --import
godot --headless --editor --path plugin --script res://test_export.gd
```

导出测试使用 `plugin/build/ohos/`，不要改写真实项目目录。更改架构选项需测试单/双架构库目录及 `abiFilters` 一致；更改导出配置需测试未加引号的 JSON5 签名保留、GLES/Vulkan `_cl_` 和 Debug 拒绝。

更新产物后重新计算并报告哈希。`verify_ohos.py` 只做静态验证，不能证明设备运行通过。工具输出“Device/emulator execution has NOT been verified”不是设备验证历史数据库。

## 运行时不可破坏的约定

- ArkTS 注入应用 files/cache/temp 目录应早于引擎初始化；`user://` 使用应用沙箱。
- 等待有效 OHNativeWindow 与非零尺寸后启动。保留 ArkUI 到 VSync 线程的主线程交接，按新 Godot 版本复核 `Main::setup/setup2/start`。
- OHOS Vulkan 的 IDENTITY preTransform 仅在支持时选择，宽高处理必须使用一致的 transform；横竖屏都需设备验证。
- GLES 路径保持 OHOS 所需扩展加载、EGL surface 创建回退和纹理/MSAA 分支。
- 当前仅 Vulkan context 初始化失败触发 GLES 回退，不要宣称所有 Vulkan 失败阶段都有回退。
- 保留 Vulkan→GLES 安全回退，除非用户明确要求其他策略；禁止以关闭回退冒充 Vulkan 修复。

## 设备与限制

鸿蒙任务使用 `devecocli` 工作流，调用前加载对应 skill。先 `devecocli device list` 确认设备；历史目标是 x86_64 `127.0.0.1:55555` 和 ARM64 手机 `192.168.1.114:33291`，不要假定手机地址永久有效。必要时可用 SDK `toolchains/hdc` 检查底层状态。

- 手机有 Vulkan 启动/布局验证记录，模拟器有 GLES virgl 验证记录，不代表全部 API/音频/生命周期验证完成。
- 当前 QEMU 没有 Vulkan ICD，也未启用 Venus/blob；补齐兼容 OpenHarmony 的 ICD 和呈现链路后才能宣称客体 Vulkan 可用。Linux glibc 驱动不能直接复制替代。
- 当前 QEMU 曾有 DRM atomic `EINVAL` 黑屏。离屏系统截图能看到 UI，不代表宿主窗口能显示；日志和实际窗口都要验证。
- 模拟器特殊重签包只用于该镜像测试，不覆盖真机云签名配置。`9568404`/`9568393` 的历史分析限定在该自定义镜像；`9568332` 是证书不一致，卸载前确认数据影响。
- 当前鼠标事件桥接与鼠标位置轮询能力不等价，`mouse_get_position()` 仍有桩实现限制。

## 后续版本迁移与交付

新官方版本在独立目录迁移：平台层、公共补丁、第三方兼容、启动/渲染、导出 API 逐项复核。搜索并更新脚本及插件中的 `4.7.2` 版本标记，不批量改历史记录。优先删除已由上游解决的重复补丁，但需用目标版本源码确认。

交付注明：实际改动、构建/测试命令及结果、未运行项、两个架构状态、真实渲染后端、产物路径/哈希与剩余问题。新版本使用匹配的官方编辑器测试；不能把静态校验、PID 存活或旧截图当作 Vulkan/显示验收成功。
