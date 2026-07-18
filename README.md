# XDR+

[English](#english) · [中文](#中文)

<a id="english"></a>

## English

Make better use of your XDR display. XDR+ is a macOS menu bar utility that enables higher SDR brightness on supported MacBook Pro displays, helping you unlock more of your screen’s potential.

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

XDR+ shows a sun icon in the menu bar. Left-click to toggle brightness enhancement; right-click to open the native system menu. It restores the system display settings when enhancement is disabled, the app quits, or the display sleeps.

### Scope and limitations

- **Supported hardware**: Intended for MacBook Pro models with a built-in XDR or mini-LED display. It isn’t guaranteed to work on SDR-only, external, or non-EDR displays. Compatibility beyond a 2021 MacBook Pro with M1 Pro has not yet been tested.
- **Results vary**: The visible result depends on the Mac model, system brightness, ambient conditions, HDR/EDR state, and macOS version. A system update can change its behavior or compatibility.
- **Not a replacement for Display settings**: XDR+ doesn’t exceed the panel’s physical peak capability and doesn’t promise a fixed brightness value or HDR result. Set the system brightness high before enabling it.
- **Hardware protection**: XDR+ doesn’t bypass macOS or the display’s built-in hardware protection. Final brightness, power draw, and thermal behavior remain controlled by the system and display hardware.
- **Restoration**: On disable, quit, or display sleep, XDR+ attempts to restore the display settings saved before enhancement. If the image still looks incorrect, quit the app or log out and back in to let macOS rebuild its display settings.

<a id="中文"></a>

## 中文

别浪费了你的 XDR 屏幕！XDR+ 是一个 macOS 菜单栏应用，可在支持的 MacBook Pro 上实现更高的 SDR 亮度，充分利用屏幕潜能。

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

XDR+ 会在菜单栏显示一个太阳图标。左键切换亮度增强，右键打开原生系统菜单。关闭、退出和屏幕睡眠时会恢复系统显示设置。

### 功能边界与注意事项

- **适用范围**：目标是配备 XDR 或 mini‑LED 内置屏的 MacBook Pro。普通 SDR 显示器、外接显示器及不支持 EDR 的屏幕不保证有效。目前仅在 2021 款 M1 Pro MacBook Pro 上测试过，其他屏幕的兼容性尚未验证。
- **效果差异**：实际提升受机型、当前系统亮度、环境光、HDR/EDR 状态和 macOS 版本影响。macOS 更新后，效果或兼容性可能发生变化。
- **不替代系统显示设置**：它不会突破面板的硬件峰值能力，也不承诺固定的亮度数值或 HDR 表现。使用前请先将系统亮度调高。
- **硬件保护**：XDR+ 不会绕过 macOS 或显示屏内置的硬件保护机制。实际展现亮度、功耗和发热始终由系统与显示屏硬件共同控制。
- **恢复机制**：关闭增强、退出应用、显示器休眠或应用异常结束后，应用会尝试恢复启动前保存的显示设置；若画面仍不正常，请退出应用或重新登录以让 macOS 重新建立显示设置。
