# Godot 4.7.2 / OpenHarmony ARM64 + x86_64 移植与插件

本目录用于构建适配 **Godot 4.7.2** 的 OpenHarmony / HarmonyOS **ARM64 + x86_64**
双架构引擎库与编辑器导出插件（`godot-ohos`）。

完整的修改清单、构建/导出流程与后续版本迁移步骤见
[`PORTING-GUIDE-ZH.md`](./PORTING-GUIDE-ZH.md)；自动化代理约定见
[`AGENTS.md`](./AGENTS.md)。

- 官方源码：`https://github.com/godotengine/godot`，`4.7.2-stable`
  (`ed1daf0bf001b61586d9930840f2f1394092c079`)。
- 鸿蒙平台层参考：`https://github.com/kdada/godot`，`openharmony`
  (`1de71ce53007388bc229472374235169dc5db950`)，已适配 4.7.2、Linux 工具链及双架构。
- 本目录就是引擎仓库根目录；平台源码位于 `platform/openharmony/`。
- 原有 GodotHub 插件桥接 ABI 不同，**请勿**与这里的库混用。

## 编译脚本与多线程编译

- `build_jobs.py`：读取 `/proc/meminfo` 与 CPU 核心数，按当前可用内存自动计算并行度
  （默认单任务按 ~1.2 GB 估算，保留 1.5 GB 给桌面，上限 8）。
- `build-x86_64.sh` / `build-arm64.sh`：分别编译 `x86_64` 与 `arm64` Release 引擎库。
- `build_dual_template.py`：将 `arm64-v8a` 与 `x86_64` 引擎库合并打包到同一模板
  `plugin/addons/godot-ohos/bin/openharmony_release_dual.zip`。
- `package_addon.py`：生成 Godot 插件压缩包 `dist/godot-ohos-4.7.2-arm64-x86_64.zip`。

常用命令：

```bash
cd /path/to/godot-OHOS

# 自动多线程编译两个架构
bash build-x86_64.sh
bash build-arm64.sh

# 如需手动指定并发数或调试目标
JOBS=4 bash build-x86_64.sh
TARGET=template_debug bash build-arm64.sh

# 合并双架构模板并打包插件 ZIP
python3 build_dual_template.py
python3 package_addon.py
```

## 交付物

- 插件安装包：[`dist/godot-ohos-4.7.2-arm64-x86_64.zip`](./dist/godot-ohos-4.7.2-arm64-x86_64.zip)
- 插件源码目录：[`plugin/addons/godot-ohos/`](./plugin/addons/godot-ohos/)
- 解压到游戏项目的 `addons/` 后得到 `addons/godot-ohos/`，在 Godot 启用插件即可在
  「项目 → 导出」中添加 **OpenHarmony** 预设并选择：
  - `arm64-v8a`
  - `x86_64`
  - `arm64-v8a + x86_64`（默认）

## 已验证内容与限制

- 已通过静态 ELF / 符号 / 依赖与模板结构校验（`verify_ohos.py`）。
- 已通过工具链与打包单元测试（`test_toolchain.py`、`test_packaging.py`）。
- 已在 Godot 4.7.2 无头模式下通过插件加载、双架构导出、单架构裁剪及 CLI 导出测试，
  并用 `devecocli build` 成功构建含 `arm64-v8a` 与 `x86_64` 双架构原生库的未签名 HAP。
- ARM64 手机已有 Vulkan 启动和横屏布局验证记录；x86_64 模拟器已有 GLES 3.2
  Mesa virgl 渲染、点击、调整尺寸及 `user://` 写入记录。音频、完整输入和生命周期
  仍需专项验收，不能把启动通过视为全部功能通过。
- 支持 Vulkan 与 GLES 3 Compatibility，按项目移动端渲染设置写入启动参数；
  Vulkan context 初始化失败时可按项目设置回退 GLES。仅分发 Release 模板，
  不支持 C# / Mono 与 ARM32。
- 当前自定义 QEMU 镜像无 Vulkan ICD，且未启用 Venus/blob，尚不能运行客体 Vulkan；
  还有 DRM atomic 提交失败导致宿主窗口黑屏的记录。系统截图有内容不代表实际输出正常。
- 当前 QEMU 的安装验证使用未签名 HAP 的 OpenHarmony 本地重签副本，不是直接安装
  真机使用的 HarmonyOS 云签名 HAP；细节见完整教程。
