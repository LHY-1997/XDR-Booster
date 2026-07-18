# XDR+

[English](#english) · [中文](#中文)

<a id="english"></a>

## English

Make better use of your XDR display. XDR+ is a macOS menu bar utility written from scratch that requests macOS’s EDR composition path to boost SDR brightness on supported MacBook Pro displays.

Most MacBook Pro models released since 2021 have an XDR display. SDR brightness is usually limited by macOS, while the panel has higher HDR/EDR headroom. Newer models may differ. XDR+ is designed for MacBook Pro models with a built-in XDR or mini-LED display.

### Run

```sh
cd XDR+
swift run
```

To build a local app bundle that can be launched by double-clicking:

```sh
./make-app.sh
open XDR+.app
```

XDR+ shows a sun icon in the menu bar. Left-click to toggle brightness enhancement; right-click to open the native system menu. When enabled, it uses a 1×1 Metal HDR surface to request macOS’s EDR composition path and applies a constrained adjustment to the original gamma table. It restores the saved gamma and ColorSync settings when enhancement is disabled, the app quits, or the display sleeps.

### Scope and limitations

- **Supported hardware**: Intended for MacBook Pro models with a built-in XDR or mini-LED display. It isn’t guaranteed to work on SDR-only, external, or non-EDR displays. Compatibility beyond a 2021 MacBook Pro with M1 Pro has not yet been tested.
- **Implementation**: Uses only public AppKit, Metal, and CoreGraphics APIs. It requests EDR with a 1×1 Metal HDR surface and adjusts the system gamma table. It contains no third-party brightness-app code, assets, or private APIs.
- **Results vary**: The visible result depends on the Mac model, system brightness, ambient conditions, HDR/EDR state, and macOS version. A system update can change its behavior or compatibility.
- **Not a replacement for Display settings**: XDR+ doesn’t exceed the panel’s physical peak capability and doesn’t promise a fixed brightness value or HDR result. Set the system brightness high before enabling it.
- **Restoration**: On disable, quit, or display sleep, XDR+ attempts to restore the gamma and ColorSync settings saved before enhancement. If the image still looks incorrect, quit the app or log out and back in to let macOS rebuild its display settings.
- **Recommended use**: Use it briefly in bright environments. Extended high-brightness use may increase power draw, heat, and battery consumption.

<a id="中文"></a>

## 中文

别浪费了你的 XDR 屏幕！XDR+ 是一个从零编写的 macOS 菜单栏应用，可在支持的 MacBook Pro 上请求 macOS 的 EDR 合成路径，从而增强 SDR 内容的亮度。

大多数 2021 年后的 MacBook Pro 都配备了 XDR 屏幕。macOS 通常会限制 SDR 亮度，而屏幕本身仍有更高的 HDR/EDR 余量；新型号的表现可能不同。XDR+ 面向配备 XDR 或 mini‑LED 内置屏的 MacBook Pro。

### 运行

```sh
cd XDR+
swift run
```

也可生成可双击启动的本地应用包：

```sh
./make-app.sh
open XDR+.app
```

XDR+ 会在菜单栏显示一个太阳图标。左键切换亮度增强，右键打开原生系统菜单。启用时，应用通过一个 1×1 的 Metal HDR 图层请求 macOS 的 EDR 合成路径，并在原始 gamma table 上施加受限的增强。关闭、退出和屏幕睡眠时会恢复 gamma/ColorSync 设置。

### 功能边界与注意事项

- **适用范围**：目标是配备 XDR 或 mini‑LED 内置屏的 MacBook Pro。普通 SDR 显示器、外接显示器及不支持 EDR 的屏幕不保证有效。目前仅在 2021 款 M1 Pro MacBook Pro 上测试过，其他屏幕的兼容性尚未验证。
- **实现方式**：应用仅使用 AppKit、Metal 和 CoreGraphics 的公开接口：以 1×1 Metal HDR 图层请求 EDR 合成路径，并通过系统 gamma table 做亮度增强。不包含第三方亮度应用的代码、资源或私有接口。
- **效果差异**：实际提升受机型、当前系统亮度、环境光、HDR/EDR 状态和 macOS 版本影响。macOS 更新后，效果或兼容性可能发生变化。
- **不替代系统显示设置**：它不会突破面板的硬件峰值能力，也不承诺固定的亮度数值或 HDR 表现。使用前请先将系统亮度调高。
- **恢复机制**：关闭增强、退出应用、显示器休眠或应用异常结束后，应用会尝试恢复启动前保存的 gamma/ColorSync 设置；若画面仍不正常，请退出应用或重新登录以让系统重新建立显示设置。
- **建议用途**：仅建议在短时、强环境光下使用。长时间高亮度可能增加功耗、发热，并影响续航。
