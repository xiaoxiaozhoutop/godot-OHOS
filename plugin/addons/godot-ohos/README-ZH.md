# godot-ohos

Godot 4.7.2 的 OpenHarmony / HarmonyOS 导出插件，支持 **ARM64（真机）** 与
**x86_64（模拟器）**，两者合并在同一套模板中，可在导出预设里选择。

本插件在接口和操作流程上对齐 `godothub/godot-ohos`，但**不是** GodotHub 官方发行版，
原生桥接 ABI 与其随附的 `libgodot_4_7.so` / `libentry_4_7.so` 不兼容，
两套产物不能混用。

## 安装

1. 将发布压缩包解压到游戏项目的 `addons` 目录，最终结构为 `addons/godot-ohos/`。
2. 已存在同名插件时，先备份旧的 `addons/godot-ohos`，再整体替换，不要混合文件。
3. 在 Godot 中打开「项目 → 项目设置 → 插件」，启用 **godot-ohos**。

```text
my_game/
├── project.godot
└── addons/
    └── godot-ohos/
        ├── plugin.cfg
        ├── godot_ohos_plugin.gd
        ├── godot_ohos_platform.gd
        ├── godot_ohos_exporter.gd
        ├── godot_ohos_filter.gd
        ├── ohos-icon.png
        └── bin/
            ├── openharmony_release_dual.zip
            └── openharmony_release_dual.manifest.json
```

## 导出

1. 打开「项目 → 导出」，添加 **OpenHarmony** 预设。
2. 设置「包 → 唯一名称」，例如 `com.example.mygame`。
3. 选择「OpenHarmony → 架构」：

   | 选项 | 产物 |
   |---|---|
   | `arm64-v8a` | 仅真机 |
   | `x86_64` | 仅模拟器 |
   | `arm64-v8a + x86_64` | 同时支持真机与模拟器（默认） |

4. 按需设置屏幕方向、SDK 版本和权限。
5. 点击「导出项目」，选择输出目录。

导出结果是**鸿蒙工程目录**（默认 `build/ohos/<项目名>`），内含：

```text
build/ohos/my_game/
├── AppScope/
├── entry/
│   ├── libs/<架构>/libgodot.so   # 引擎库，随所选架构生成
│   └── src/main/resources/rawfile/template.pck
├── build-profile.json5
└── oh-package.json5
```

用 DevEco Studio 打开该目录，再签名、打包、安装。

命令行导出（预设名以实际为准）：

```bash
godot --headless --path /path/to/game \
  --export-release "OpenHarmony" build/ohos/my_game
```

本插件只负责生成鸿蒙工程，不构建、不签名、不安装 HAP。

## 架构二合一如何工作

`bin/openharmony_release_dual.zip` 内含两个架构的引擎库：

```text
entry/libs/arm64-v8a/libgodot.so
entry/libs/x86_64/libgodot.so
```

导出时插件按所选架构裁剪 `entry/libs/`，并同步改写 `entry/build-profile.json5`
的 `abiFilters`。因此：

- 一个插件分发包同时覆盖真机和模拟器；
- 只选 x86_64 时，产物只有 x86_64 库，模拟器安装包体积不会翻倍；
- 选双架构时，HAP 同时包含两种 `libgodot.so`。

`entry/src/main/cpp/napi_init.cpp` 会由鸿蒙工具链按 `abiFilters` 分别为每个架构
编译 `libentry.so`，无需手工处理。

## 渲染与运行要求

- 引擎同时支持 **Vulkan**（`mobile` / `forward_plus`）与 **OpenGL ES 3**
  （`gl_compatibility` / `opengl3`）渲染；若设备或模拟器没有 Vulkan ICD，
  Vulkan 也会自动回退到 `opengl3`（`gl_compatibility`）。
- 导出预设只支持 **Release** 原生模板，选择调试导出会给出明确报错，
  不会用 Release 模板冒充。
- 不支持 ARM32、C# / Mono。
- GDExtension 需另行提供对应 OHOS 架构的二进制，插件不代为编译。
- 导出时写入的启动参数会根据项目的移动端渲染设置写入对应的
  `--rendering-method` 与 `--rendering-driver`（`gl_compatibility` 使用
  `opengl3`，其余使用 `vulkan`），不会改动项目自身的渲染设置。

## 后续步骤

1. 用 DevEco Studio 打开导出的工程目录，配置签名。
2. 或使用命令行工具：

   ```bash
   export DEVECO_CLI_CLT_PATH=/path/to/command-line-tools
   cd build/ohos/my_game
   devecocli build --modules entry --build-mode release
   ```

   未签名产物位于
   `entry/build/default/outputs/default/entry-default-unsigned.hap`。
3. 用 `devecocli signature generate` 生成签名材料后重新构建并安装。

本插件不包含证书、密钥或任何个人签名信息。

## 来源与许可

引擎基于 Godot 官方 `4.7.2-stable`；鸿蒙平台层参考 `kdada/godot` 的
`openharmony` 分支，并做了 4.7.2 适配、Linux 工具链适配和双架构支持。
Godot 与相关第三方依赖的许可分别见 `LICENSE.txt` 和 `COPYRIGHT.txt`。
本插件脚本以 MIT 许可提供。
