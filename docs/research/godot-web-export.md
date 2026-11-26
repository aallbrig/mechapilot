# Godot 4.7.2 web export: single-threaded, headless CI export, touch, pinned templates

Research for [#2](https://github.com/aallbrig/mechapilot/issues/2) (map: [#1](https://github.com/aallbrig/mechapilot/issues/1)). Researched 2026-11-26 against Godot 4.7.2-stable (released 2026-08-18).

**Question.** How do we export a strict-GDScript Godot 4.7.2 3D project to the web so it runs on GitHub Pages and S3/CloudFront with no COOP/COEP headers, on desktop and mobile touch browsers? How do we run the export headless in GitHub Actions and locally with pinned templates? Which Action or install method should we use? How big is the build and how fast does it load? What are the Compatibility renderer's limits on the web?

## TL;DR: recommendations

1. **Use a single-threaded export.** Set `variant/thread_support=false` (the default) and `variant/extensions_support=false`. The build then needs only HTTPS. It needs no COOP/COEP headers, no SharedArrayBuffer and no PWA service-worker workaround. [docs][web]
2. **Use the Compatibility renderer.** Set `rendering/renderer/rendering_method="gl_compatibility"` for every platform, not only `.web`, so desktop play-testing matches what ships. WebGL 2 through Compatibility is the only renderer Godot supports on the web. [docs][web] [renderers]
3. **Install Godot and the templates with our own POSIX `sh` script, not a marketplace Action.** `task setup` and CI call the same script. It reads `.godot-version`, downloads the official editor zip and `.tpz` from the `godotengine/godot` GitHub release, checks them against the release's `SHA512-SUMS.txt`, and installs only the `web_*` templates. CI caches the result with `actions/cache` keyed on `.godot-version`. The fallback is `chickensoft-games/setup-godot@v2.4.3`, pinned by SHA, with `use-dotnet: false`.
4. **Export command:** `godot --headless --path <project> --import`, then `godot --headless --path <project> --export-release "Web" build/web/index.html`. A failed export exits non-zero. [cli] [src-editor]
5. **Precompress `.wasm`, `.pck` and `.js` (Brotli and gzip) before uploading to S3.** CloudFront compresses nothing larger than 10,000,000 bytes, and `godot.wasm` is 39.5 MB. Set `Content-Type: application/wasm` explicitly. [cf-compress]
6. **Export preset:** turn on both `vram_texture_compression/for_desktop` and `for_mobile`. The second one also needs `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot`. Without it the export fails with a misleading "No export template found" error (verified locally; see Gotchas).

## Key facts later tickets depend on

| Fact | Value | Source |
|---|---|---|
| Pinned version string | `4.7.2-stable` (release tag); `4.7.2.stable` (template dir name) | [release], local run |
| Template install dir (Linux CI) | `~/.local/share/godot/export_templates/4.7.2.stable/` | [godot-ci] uses this path; Godot data dir on Linux |
| Template install dir (macOS) | `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` | local error message from `godot` 4.7.2 |
| Template files needed (single-threaded, no GDExtension) | `web_nothreads_release.zip`, `web_nothreads_debug.zip` (about 10 MB each), plus `version.txt` | `.tpz` listing, [src-web] `_get_template_name` |
| Full `.tpz` size | 1,281,349,702 bytes (all platforms) | [release] |
| Editor for Linux CI | `Godot_v4.7.2-stable_linux.x86_64.zip` (77.9 MB). Run with `--headless`; there is no separate headless build in 4.x. | [release], [cli] |
| Editor for macOS | `Godot_v4.7.2-stable_macos.universal.zip` | [release] |
| Checksums | `SHA512-SUMS.txt` on the release (e.g. tpz `ca4d71c4…ccb84079`) | [release] |
| Thread support | `variant/thread_support` defaults to `false`; with false, "it only needs HTTPS" | [src-web] L375, [class-web] |
| Canvas resize default | `html/canvas_resize_policy=2` (Adaptive: fills the page) | [src-web] L382 |
| Default playback type on web | `audio/general/default_playback_type.web = 1` (Sample) | local `ProjectSettings` probe |
| Touch emulation defaults | `input_devices/pointing/emulate_mouse_from_touch = true`, `emulate_touch_from_mouse = false` | local `ProjectSettings` probe |
| Lights per mesh (Compatibility) | `rendering/limits/opengl/max_lights_per_object = 8` (can be raised) | [renderers], local probe |
| C# on web | Not supported in Godot 4. GDScript only. Never use a `mono`/.NET editor to export. | [web], [src-web] L425 |

## 1. Single-threaded export, and hosting with no special headers

- Since Godot 4.3, single-threaded export is the default and preferred option. It "needs no special server headers", cannot use threads, and is "more compatible overall". Multi-threaded export (`variant/thread_support=true`) needs SharedArrayBuffer, which needs `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. [web] [4.3-progress]
- `variant/extensions_support=true` (GDExtension) also needs those headers, so keep it off. We use plain GDScript, so we don't need it. [web]
- The PWA option can fake the headers with a service worker. We don't need it. Leave `progressive_web_app/enabled=false` so no service worker caches stale builds across QA deploys. [web] [class-web]
- Export output for `export_path=".../index.html"`: `index.html`, `index.js`, `index.wasm`, `index.pck`, `index.png` (boot splash), `index.icon.png`, `index.apple-touch-icon.png`, `index.audio.worklet.js`, `index.audio.position.worklet.js`. Deploy all of them together and don't rename them. [web], local export
- **Serving:** `.wasm` must be `application/wasm`. Other types disable streaming compilation. `.pck` is `application/octet-stream`. Server-side compression is recommended. Gzip shrinks the wasm to about a quarter, and Brotli does better. [web]
- **GitHub Pages (QA, under `/game/`)** compresses with gzip on the fly, according to Godot's docs. [web] Because the export uses relative paths, a sub-path like `/game/` works without changes. The 39.5 MB wasm is under the per-file limit for Pages.
- **S3 + CloudFront (Production):** CloudFront compresses only objects between 1,000 and 10,000,000 bytes that have a listed Content-Type. `application/wasm` is listed, but the wasm is about 4x the size cap, so CloudFront serves it uncompressed (39.5 MB). If the origin sends a `Content-Encoding` header, CloudFront passes the object through and caches it as is. [cf-compress] Options:
  - **Recommended:** upload `index.wasm`, `index.pck` and `index.js` gzip-precompressed, with `Content-Encoding: gzip` and the correct `Content-Type`. Gzip is universal, and a single S3 object can't negotiate between encodings. For Brotli we would need a CloudFront Function that rewrites to `.br` objects when `Accept-Encoding` includes `br`. That saves about 3 MB (see sizes below). This is optional, and the infra ticket decides.
  - Leave CloudFront's automatic compression on for the small files (`.html`, `.js` if not precompressed).
- `user://` storage (our local Scoreboard) is IndexedDB. It needs cookies or storage to be allowed, it doesn't persist in private browsing, and `OS.is_userfs_persistent()` can return a false positive. [web]

## 2. Headless export, locally and in GitHub Actions

### Commands (verified locally with 4.7.2 on macOS)

```sh
godot --headless --path "$PROJECT" --import                                     # populate .godot/ on a fresh clone
godot --headless --path "$PROJECT" --export-release "Web" build/web/index.html  # dir must exist; path is relative to project.godot
```

- `--headless` is required on machines without a GPU, such as CI. [cli]
- `--export-release <preset> <path>`: the preset name must match `export_presets.cfg`. The target directory must already exist. A relative path resolves against the directory that holds `project.godot`, not the current working directory. [cli]
- The docs say `--export-debug`, `--export-pack` and `--export-patch` imply `--import`. Run `--import` explicitly first anyway, because it is cheap, and a fresh CI checkout has no `.godot/` cache (class names, autoloads, imported assets). A trivial project exported fine from a clean `.godot/` without it, but don't depend on that with `class_name` and autoload scripts. [cli], local test
- On failure, the editor runs `_exit_editor(EXIT_FAILURE)`, so `task` and CI see a non-zero exit. [src-editor]
- Export time for a trivial 3D scene: about 1.8 s wall-clock on an M-series Mac (local).
- `export_presets.cfg` must be committed. It has no secrets for the web platform. Exporting doesn't check strict GDScript warnings, so the separate `task ci` lint and test step stays the gate.

### Template lookup

The exporter looks for `<data dir>/export_templates/4.7.2.stable/web_nothreads_{debug,release}.zip` (`web_dlink_*` if extensions are on; no `nothreads` if threads are on). [src-web] An alternative is `custom_template/debug` and `custom_template/release` in the preset, set to absolute zip paths (verified working locally). Absolute paths in a committed preset aren't portable, though, so we prefer the standard directory.

### Install method: comparison

| Option | Pinned? | Integrity | Cache size | Local parity | Notes |
|---|---|---|---|---|---|
| **Own `scripts/install-godot.sh`** (recommended) | Reads `.godot-version` | SHA512 vs `SHA512-SUMS.txt` | about 100 MB (editor + 2 web templates) | Same script used by `task setup` | Fits the standing "POSIX sh + ShellCheck" and "pinned Actions" decisions; no third-party code |
| `chickensoft-games/setup-godot` v2.4.3 (2026-10-01) | `version:` input | None | Whole extracted template set, over 1 GB, keyed on URL | No (CI only) | `use-dotnet` defaults to `true`, which would break web export; must set `false`. `include-templates: true` downloads the full 1.28 GB `.tpz`. [setup-godot] |
| `firebelley/godot-export` v8.0.0 (2026-05-28) | Via URL inputs | None | Full `.tpz` | No | Wraps the export command itself; less control over flags. [godot-export] |
| `barichello/godot-ci:4.7.2` Docker image (2026-08-18) | Image tag | Image digest | Image pull, about 1+ GB | Docker only | Templates preinstalled under `/root/.local/share/godot/…`; jobs run as a container. [godot-ci] |

**Sketch of the recommended script** (for the build ticket, not final):

```sh
#!/bin/sh
set -eu
ver=$(cat .godot-version)            # e.g. 4.7.2
tag="${ver}-stable"; dir_ver="${ver}.stable"
base="https://github.com/godotengine/godot/releases/download/${tag}"
# 1. download Godot_v${tag}_linux.x86_64.zip (or macos.universal.zip) + Godot_v${tag}_export_templates.tpz + SHA512-SUMS.txt
# 2. sha512sum -c against the matching lines (shasum -a 512 on macOS)
# 3. unzip editor into a tool dir on PATH
# 4. unzip -j the .tpz 'templates/web_nothreads_*.zip' 'templates/version.txt' into
#    ${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${dir_ver}/      (Linux)
#    "$HOME/Library/Application Support/Godot/export_templates/${dir_ver}/"       (macOS)
```

CI: `actions/cache` (pinned by SHA) on the tool dir and template dir, keyed on `hashFiles('.godot-version')`. The 1.28 GB `.tpz` download happens only on a cache miss. A `.tpz` is a zip, so in principle HTTP range reads can pull just the 10 MB web templates without downloading 1.28 GB (done for this research), but a plain download is simpler and is cached anyway.

## 3. Build size and load time

Measured: a 4.7.2 export of a one-box 3D scene with the official `web_nothreads_release` template (sizes in bytes):

| File | Raw | gzip -9 | brotli -q 11 |
|---|---|---|---|
| `index.wasm` | 39,514,754 | 10,054,769 | 6,902,599 |
| `index.js` | 279,815 | 68,480 | 59,854 |
| `index.pck` (trivial game) | 4,960 | 1,995 | 1,774 |
| `index.html` + worklets + PNGs | about 55 KB | about 42 KB | about 41 KB |
| **Total** | **about 39.9 MB** | **about 10.2 MB** | **about 7.0 MB** |

- The engine wasm dominates the size. Our primitive-mesh game's `.pck` should stay small (hundreds of KB to a few MB). Expect a first-load transfer of about 10 MB gzip or about 7 MB Brotli. Uncompressed, from CloudFront without precompression, it would be about 40 MB.
- Load time (estimate, not measured on devices): about 10 MB at 50 Mbps is roughly 2 s of download, plus wasm compile and engine init (typically 1-3 s on desktop, more on mid-range phones). On a 10 Mbps mobile link, expect about 8-10 s on first visit. Repeat visits are fast if the files are cached. Use long `Cache-Control` max-age only with versioned or immutable paths, or else keep a short TTL and invalidate on deploy.
- Further reduction is possible with a custom size-optimized template that strips unused modules, which Godot's docs suggest for mobile. [web] That means compiling Godot with Emscripten, so it's out of scope unless load time turns out to be a problem.

## 4. Touch and mobile browsers

- Godot's web platform delivers browser touch events as `InputEventScreenTouch` and `InputEventScreenDrag`, with multi-touch indices. [inputevent]
- `input_devices/pointing/emulate_mouse_from_touch` defaults to `true`, so `Control` UI and mouse-click handlers also work with a single-finger tap. For in-game touch controls (multi-touch), handle `InputEventScreenTouch` and `InputEventScreenDrag` directly. Don't rely on emulated mouse events, which carry only one pointer. For desktop testing of touch code, turn on `emulate_touch_from_mouse` in a debug override. (Defaults from a local `ProjectSettings` probe.)
- `html/experimental_virtual_keyboard` shows the on-screen keyboard on touch devices for `LineEdit`/`TextEdit`. Enable it only if the game has text entry, such as Scoreboard initials. [class-web]
- Fullscreen and mouse capture must be requested from inside an input-event callback (`_input`, `_unhandled_input`, a button press). Audio can't start until a user gesture, so put a "tap to start" screen first. [web]
- `progressive_web_app/orientation` can force landscape, but only when installed as a PWA. A normal browser tab ignores it. Handle portrait with an adaptive camera or HUD, or with a "rotate your device" overlay. [class-web]
- Performance on mobile is limited, and Safari has WebGL 2 issues that other browsers don't, so Chromium-based browsers and Firefox are preferred. Plan a real-device smoke test on iOS Safari and Android Chrome as part of QA sign-off. [web]
- Keep `vram_texture_compression/for_mobile=true`, which uses ETC2/ASTC for phones, alongside `for_desktop` (S3TC/BPTC). Both together make the export bigger but more compatible. With primitive meshes and little texture data, the cost is negligible. [web] [class-web]

## 5. Compatibility renderer limits relevant to the port

Compatibility (WebGL 2 on the web) is the only web renderer. WebGPU isn't supported yet. [web] [renderers]

- **Lights:** 8 Omni/Spot lights per mesh (adjustable via `rendering/limits/opengl/max_lights_per_object`); up to 8 DirectionalLights. Shadowed lights use multi-pass with less accurate blending. No light projector textures. No PCSS. [renderers]
- **GI and reflections:** no VoxelGI, SDFGI or SSIL. LightmapGI can be rendered but not baked on Compatibility. ReflectionProbe is limited to 2 per mesh. [renderers]
- **Post-processing:** glow, tonemapping, adjustments, depth/height fog and SSAO are supported. Not supported: SSR, volumetric fog, depth-of-field blur, CompositorEffects, FXAA, SMAA, TAA and FSR2. MSAA 3D is supported. [renderers]
- **Other:** no decals, no particle trails or SDF collision, no compute shaders, no RenderingDevice access. Color is RGBA8 LDR, and depth is 24-bit without reverse-Z, so avoid huge camera far/near ratios. [renderers]
- **Audio on web:** the default "Sample" playback has no AudioEffects (reverb, filters), and positional audio may be unreliable. "Stream" mode supports effects but adds latency. [web]
- **Background tab:** the browser pauses the game when its tab is hidden. [web]

None of these block a primitive-mesh, Level 1 parity port. Design lighting for a few dynamic lights with forward shading, without screen-space effects.

## Gotchas found while verifying

1. **Misleading error.** With `vram_texture_compression/for_mobile=true` and no `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot`, `has_valid_project_configuration` returns false and gives no message ([src-web] around L471). The CLI then prints only the template lookup paths ("No export template found at the expected path") even when custom templates are valid. Always set the ETC2/ASTC import setting explicitly in `project.godot`.
2. A hand-written `export_presets.cfg` without `include_filter` and `exclude_filter` logs `ConfigFile` errors. Generate the preset once from the editor, or include every standard key.
3. `setup-godot` defaults `use-dotnet: true`, and a .NET editor refuses web export outright ([src-web] L425).

## Sources

- [web]: Godot 4.7 docs, *Exporting for the Web*. https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
- [class-web]: Godot 4.7 docs, *EditorExportPlatformWeb*. https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html
- [cli]: Godot 4.7 docs, *Command line tutorial*. https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- [renderers]: Godot 4.7 docs, *Overview of renderers*. https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- [inputevent]: Godot 4.7 docs, *Using InputEvent*. https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html
- [4.3-progress]: Godot blog, *Web Export in 4.3*. https://godotengine.org/article/progress-report-web-export-in-4-3/
- [release]: Godot 4.7.2-stable release assets and `SHA512-SUMS.txt`. https://github.com/godotengine/godot/releases/tag/4.7.2-stable
- [src-web]: `platform/web/export/export_plugin.cpp` @ 4.7.2-stable. https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/export/export_plugin.cpp
- [src-editor]: `editor/editor_node.cpp` @ 4.7.2-stable (CLI export path, around L1395-1420). https://github.com/godotengine/godot/blob/4.7.2-stable/editor/editor_node.cpp
- [cf-compress]: AWS docs, *Serve compressed files* (CloudFront). https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/ServingCompressedFiles.html
- [setup-godot]: https://github.com/chickensoft-games/setup-godot (`action.yml`, `src/main.ts`; latest v2.4.3)
- [godot-export]: https://github.com/firebelley/godot-export (latest v8.0.0)
- [godot-ci]: https://github.com/abarichello/godot-ci, Docker Hub `barichello/godot-ci` (tag `4.7.2`)
- Local verification: Godot `4.7.2.stable.official.ed1daf0bf` on macOS. Headless export of a minimal 3D scene with the official `web_nothreads_*` templates taken from the release `.tpz`; sizes measured with `gzip -9` and `brotli -q 11`; defaults read via `ProjectSettings.get_setting` in a `--script` probe.
