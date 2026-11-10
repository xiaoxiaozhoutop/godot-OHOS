# godot-ohos

Godot 4.7.2 export plugin for OpenHarmony / HarmonyOS, supporting **ARM64
(devices)** and **x86_64 (emulator)** from a single bundled template.

The workflow mirrors `godothub/godot-ohos`, but this is **not** an official
GodotHub release. Its native bridge ABI differs from the `libgodot_4_7.so` /
`libentry_4_7.so` shipped by that plugin, so the two cannot be mixed.

## Install

1. Extract the release archive into your project's `addons` directory, giving
   `addons/godot-ohos/`.
2. If a plugin with that name already exists, back it up and replace the whole
   folder. Do not merge files.
3. Enable **godot-ohos** in Project → Project Settings → Plugins.

## Export

1. Project → Export, add an **OpenHarmony** preset.
2. Set Package → Unique Name, for example `com.example.mygame`.
3. Pick OpenHarmony → Architectures:

   | Option | Result |
   |---|---|
   | `arm64-v8a` | Devices only |
   | `x86_64` | Emulator only |
   | `arm64-v8a + x86_64` | Both (default) |

4. Configure orientation, SDK version and permissions as needed.
5. Export the project and choose an output directory.

The export produces an **OHOS project directory** (default
`build/ohos/<project name>`) containing the game PCK and the engine library for
the selected architectures. Open it in DevEco Studio to sign, package and run.

Command line:

```bash
godot --headless --path /path/to/game \
  --export-release "OpenHarmony" build/ohos/my_game
```

This plugin only generates the OHOS project. It does not build, sign or
install a HAP.

## How the dual architecture works

`bin/openharmony_release_dual.zip` carries both engine libraries:

```text
entry/libs/arm64-v8a/libgodot.so
entry/libs/x86_64/libgodot.so
```

During export the plugin prunes `entry/libs/` down to the selected
architectures and rewrites `abiFilters` in `entry/build-profile.json5`
accordingly. So one addon distribution covers devices and emulators, and
selecting only `x86_64` keeps the HAP size down.

`entry/src/main/cpp/napi_init.cpp` is compiled per architecture by the OHOS
toolchain according to `abiFilters`; no manual handling is needed.

## Rendering and runtime requirements

- Both **Vulkan** (`mobile` / `forward_plus`) and **OpenGL ES 3**
  (`gl_compatibility` / `opengl3`) are implemented. When a device or emulator
  lacks a Vulkan ICD, Vulkan automatically falls back to `opengl3`
  (`gl_compatibility`).
- Only **Release** native templates are bundled. Choosing a debug export
  reports an explicit error instead of silently using the release template.
- ARM32 and C# / Mono are not supported.
- GDExtension libraries must be provided separately for OHOS.
- The export writes `--rendering-method` and `--rendering-driver` into
  `entry/src/main/resources/rawfile/_cl_` based on the project's mobile
  rendering method (`gl_compatibility` → `opengl3`; otherwise `vulkan`)
  without modifying the project's own settings.

## Next steps

1. Open the exported project in DevEco Studio and configure signing.
2. Or use the command line tools:

   ```bash
   export DEVECO_CLI_CLT_PATH=/path/to/command-line-tools
   cd build/ohos/my_game
   devecocli build --modules entry --build-mode release
   ```

   The unsigned output is
   `entry/build/default/outputs/default/entry-default-unsigned.hap`.
3. Generate signing material with `devecocli signature generate`, then rebuild
   and install.

No certificates, keys or personal signing data are bundled.

## Source and license

The engine is based on Godot's official `4.7.2-stable`. The OpenHarmony
platform layer follows the `openharmony` branch of `kdada/godot`, adapted for
4.7.2, the Linux toolchain and dual architecture support. See `LICENSE.txt` and
`COPYRIGHT.txt` for Godot and third-party licenses. The plugin scripts are
provided under the MIT license.
