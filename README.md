# XDR+

别浪费了你的XDR屏幕！一个从零编写的 macOS 菜单栏应用，使SDR亮度达到1000尼特！
21年以后的MacBook Pro均配备了XDR屏幕，但是SDR情况下苹果只开放到500尼特（25年新款MacBook Pro 原生SDR亮度可达1000尼特）。XDR屏幕峰值亮度实际可达1600尼特，持续亮度可达1000尼特。
用于配备 XDR/mini-LED 内置屏的 MacBook Pro。

## English

Make better use of your XDR display. XDR+ is a macOS menu bar utility written from scratch that requests macOS’s EDR composition path to boost SDR brightness on supported MacBook Pro displays.

It is designed for MacBook Pro models with built-in XDR or mini-LED displays. Most MacBook Pro models released since 2021 include an XDR display: SDR brightness is typically limited by the system, while the panel has higher HDR/EDR headroom. Actual results vary by model, macOS version, ambient conditions, and current display state.

XDR+ uses public AppKit, Metal, and CoreGraphics APIs only. It creates a 1×1 Metal HDR surface and applies a constrained adjustment to the original gamma table. The original display settings are restored when enhancement is disabled, the app quits, or the display sleeps.

## 运行

```sh
cd XDR+
swift run
```

也可生成可双击启动的本地应用包：

```sh
./make-app.sh
open XDR+.app
```

它会在菜单栏显示一个太阳图标。左键切换亮度增强，右键打开原生系统菜单。启用时，应用通过一个 1×1 的 Metal HDR 图层请求 macOS 的 EDR 合成路径，并在原始 gamma table 上施加受限的增强。关闭、退出和屏幕睡眠时会恢复 gamma/ColorSync 设置。

## 功能边界与注意事项

- **适用范围**：目标是配备 XDR 或 mini‑LED 内置屏的 MacBook Pro。普通 SDR 显示器、外接显示器及不支持 EDR 的屏幕不保证有效。（本人目前只有2021款MacBook Pro with M1 Pro，暂时无法测试其他屏幕的兼容性）
- **实现方式**：应用仅使用 AppKit、Metal 和 CoreGraphics 的公开接口：以 1×1 Metal HDR 图层请求 EDR 合成路径，并通过系统 gamma table 做亮度增强。不包含第三方应用的代码、资源或私有接口。
- **效果差异**：实际提升受机型、当前系统亮度、环境光、HDR/EDR 状态和 macOS 版本影响。macOS 更新后，效果或兼容性可能发生变化。
- **不替代系统显示设置**：它不会突破面板的硬件峰值能力，也不承诺固定的亮度数值或 HDR 表现。使用前请先将系统亮度调高。
- **恢复机制**：关闭增强、退出应用、显示器休眠或应用异常结束后，应用会尝试恢复启动前保存的 gamma/ColorSync 设置；若画面仍不正常，请退出应用或重新登录以让系统重新建立显示设置。
- **建议用途**：仅建议在短时、强环境光下使用。长时间高亮度可能增加功耗、发热，并影响续航。
