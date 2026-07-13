# XDR Lift

一个从零编写的 macOS 菜单栏应用，用于配备 XDR/mini-LED 内置屏的 MacBook Pro。

## 运行

```sh
cd XDRLift
swift run
```

也可生成可双击启动的本地应用包：

```sh
./make-app.sh
open XDRLift.app
```

它会在菜单栏显示一个太阳图标。左键切换亮度增强，右键打开原生系统菜单。启用时，应用通过一个 1×1 的 Metal HDR 图层请求 macOS 的 EDR 合成路径，并在原始 gamma table 上施加受限的增强。关闭、退出和屏幕睡眠时会恢复 gamma/ColorSync 设置。

## 当前边界

它只使用 AppKit、Metal 和 CoreGraphics 的公开接口；不含第三方亮度应用的代码、视频、图标或品牌资源。该方法依赖 macOS 的 HDR 合成行为，系统更新可能改变实际效果。启用前请将系统亮度调到最高，并只在短时高环境光需求下使用。
