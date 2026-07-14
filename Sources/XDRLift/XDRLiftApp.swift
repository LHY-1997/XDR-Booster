import AppKit
import CoreGraphics
import MetalKit
import ServiceManagement

@main
struct XDRLiftApp {
    static func main() {
        // 以“菜单栏辅助应用”模式运行：不会出现在 Dock 或 Cmd-Tab 切换器中。
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    // 显示增强控制器：负责 EDR 检测、Gamma 写入及恢复。
    private let booster = XDRBooster()
    private var statusItem: NSStatusItem?
    private lazy var settingsWindowController = SettingsWindowController(booster: booster) { [weak self] in
        self?.refreshIcon()
    }
    private lazy var menuSliderControl = MenuSliderControl { [weak self] value in
        self?.booster.multiplier = value
        // 设置窗口若已创建，拖动菜单栏滑块时也立即同步其中的数值和位置。
        self?.settingsWindowController.refreshControls()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建可随菜单栏宽度变化的状态栏图标。
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        guard let button = item.button else { return }
        button.image = symbol("sun.max")
        button.target = self
        button.action = #selector(showPanel)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 无论从菜单退出还是由系统终止，都优先还原显示设置。
        booster.disable(reason: "已恢复系统显示设置")
    }

    @objc private func showPanel() {
        // 左键快速开关；右键才显示原生 NSMenu，以便由系统负责菜单定位与材质。
        if NSApp.currentEvent?.type == .rightMouseUp {
            guard let statusItem else { return }
            statusItem.popUpMenu(makeSystemMenu())
            return
        }
        booster.isEnabled ? booster.disable() : booster.enable()
        refreshIcon()
        settingsWindowController.refreshControls()
    }

    private func makeSystemMenu() -> NSMenu {
        // 每次展开时重新创建菜单，使勾选状态和强度数值始终是最新的。
        let menu = NSMenu()
        menu.autoenablesItems = false

        let toggle = NSMenuItem(title: "亮度增强", action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        toggle.state = booster.isEnabled ? .on : .off
        toggle.isEnabled = booster.isSupported || booster.isEnabled
        menu.addItem(toggle)

        menu.addItem(makeStrengthItem())
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    private func makeStrengthItem() -> NSMenuItem {
        let item = NSMenuItem()
        // 由滑块右边缘决定菜单宽度，避免菜单比内容宽出一大截。
        let width: CGFloat = 176
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 53))
        // AppKit 在未勾选时会收回左侧的勾选栏；自定义强度行也要同步移动，
        // 才能让“强度”首字和滑块与系统菜单项目对齐。
        let textLeading: CGFloat = booster.isEnabled ? 28 : 13
        let sliderLeading: CGFloat = booster.isEnabled ? 30 : 16
        let sliderWidth: CGFloat = 140
        let label = NSTextField(labelWithString: "强度")
        // 与当前勾选状态下 AppKit 的标题列对齐。
        label.frame = NSRect(x: textLeading, y: 31, width: 76, height: 16)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        let value = NSTextField(labelWithString: String(format: "× %.2f", booster.multiplier))
        value.frame = NSRect(x: textLeading + 38, y: 31, width: 76, height: 16)
        value.alignment = .left
        value.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let slider = NSSlider(value: booster.multiplier, minValue: 1.05, maxValue: 1.75, target: menuSliderControl, action: #selector(MenuSliderControl.changed(_:)))
        // NSSlider 的轨道和圆形滑块会略微超出 frame，因此在窄菜单右侧保留安全边距。
        slider.frame = NSRect(x: sliderLeading, y: 7, width: sliderWidth, height: 22)
        slider.isContinuous = true
        // 即使当前未开启，也允许预先设置下次启用时的强度。
        slider.isEnabled = true
        menuSliderControl.valueLabel = value
        container.addSubview(label)
        container.addSubview(value)
        container.addSubview(slider)
        item.view = container
        return item
    }

    @objc private func toggleFromMenu() {
        booster.isEnabled ? booster.disable() : booster.enable()
        refreshIcon()
        settingsWindowController.refreshControls()
    }

    @objc private func openSettings() {
        // 让设置窗口成为前台窗口；菜单栏应用默认不会自动获得焦点。
        settingsWindowController.refreshControls()
        settingsWindowController.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func refreshIcon() {
        // 开启后使用实心太阳，关闭时使用描边太阳。
        statusItem?.button?.image = symbol(booster.isEnabled ? "sun.max.fill" : "sun.max")
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "XDR Lift")
        image?.isTemplate = true
        return image
    }
}

@MainActor
private final class MenuSliderControl: NSObject {
    weak var valueLabel: NSTextField?
    private let onChange: (CGFloat) -> Void

    init(onChange: @escaping (CGFloat) -> Void) {
        self.onChange = onChange
    }

    @objc func changed(_ sender: NSSlider) {
        // 滑块连续拖动时立即更新增强参数和旁边的倍率文本。
        onChange(CGFloat(sender.doubleValue))
        valueLabel?.stringValue = String(format: "× %.2f", sender.doubleValue)
    }
}

@MainActor
private final class SettingsWindowController: NSWindowController {
    init(booster: XDRBooster, changed: @escaping () -> Void) {
        let controller = SettingsViewController(booster: booster, changed: changed)
        let window = NSWindow(contentViewController: controller)
        window.title = "XDR Lift 设置"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 380, height: 310))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    // 供菜单栏操作调用：窗口打开时即时更新；关闭时也安全地更新下次显示的状态。
    func refreshControls() {
        (contentViewController as? SettingsViewController)?.refreshControls()
    }
}

@MainActor
private final class SettingsViewController: NSViewController {
    private let booster: XDRBooster
    private let changed: () -> Void
    private let brightnessToggle = NSButton(checkboxWithTitle: "亮度增强", target: nil, action: nil)
    private let strength = NSSlider(value: 1.45, minValue: 1.05, maxValue: 1.75, target: nil, action: nil)
    private let strengthValue = NSTextField(labelWithString: "")
    private let launchAtLogin = NSButton(checkboxWithTitle: "登录时启动 XDR Lift", target: nil, action: nil)

    init(booster: XDRBooster, changed: @escaping () -> Void) {
        self.booster = booster
        self.changed = changed
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        // 使用普通设置窗口和系统控件，跟随 macOS 的字体、颜色及辅助功能设置。
        let content = NSView()
        view = content

        let displayTitle = sectionTitle("显示")
        brightnessToggle.target = self
        brightnessToggle.action = #selector(toggleBoost)

        let sliderTitle = NSTextField(labelWithString: "强度")
        sliderTitle.font = .systemFont(ofSize: 13)
        strengthValue.alignment = .right
        strengthValue.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let sliderHeader = NSStackView(views: [sliderTitle, NSView(), strengthValue])
        sliderHeader.orientation = .horizontal
        sliderHeader.alignment = .centerY

        strength.target = self
        strength.action = #selector(strengthChanged)
        strength.isContinuous = true
        let displayGroup = NSStackView(views: [displayTitle, brightnessToggle, sliderHeader, strength])
        displayGroup.orientation = .vertical
        displayGroup.alignment = .leading
        displayGroup.spacing = 8

        let generalTitle = sectionTitle("通用")
        launchAtLogin.target = self
        launchAtLogin.action = #selector(launchAtLoginChanged)
        let generalGroup = NSStackView(views: [generalTitle, launchAtLogin])
        generalGroup.orientation = .vertical
        generalGroup.alignment = .leading
        generalGroup.spacing = 8

        let divider = NSBox()
        divider.boxType = .separator
        let quitButton = NSButton(title: "退出 XDR Lift", target: self, action: #selector(quit))
        quitButton.bezelStyle = .rounded
        let footer = NSStackView(views: [NSView(), quitButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY

        let root = NSStackView(views: [displayGroup, generalGroup, divider, footer])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            displayGroup.widthAnchor.constraint(equalTo: root.widthAnchor),
            generalGroup.widthAnchor.constraint(equalTo: root.widthAnchor),
            divider.widthAnchor.constraint(equalTo: root.widthAnchor),
            footer.widthAnchor.constraint(equalTo: root.widthAnchor),
            sliderHeader.widthAnchor.constraint(equalTo: root.widthAnchor),
            strength.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
        refreshControls()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshControls()
    }

    @objc private func strengthChanged() {
        booster.multiplier = CGFloat(strength.doubleValue)
        updateSliderValue()
    }

    @objc private func toggleBoost() {
        booster.isEnabled ? booster.disable() : booster.enable()
        changed()
        refreshControls()
    }

    @objc private func launchAtLoginChanged() {
        do {
            if launchAtLogin.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 注册失败时回滚复选框，避免界面显示与系统实际状态不一致。
            launchAtLogin.state = launchAtLoginEnabled ? .on : .off
            presentError(error)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // 从共享的 booster 读取状态，避免设置窗口维护自己的副本而产生不同步。
    func refreshControls() {
        booster.refresh()
        brightnessToggle.state = booster.isEnabled ? .on : .off
        brightnessToggle.isEnabled = booster.isSupported || booster.isEnabled
        strength.doubleValue = booster.multiplier
        updateSliderValue()
        launchAtLogin.state = launchAtLoginEnabled ? .on : .off
    }

    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func updateSliderValue() {
        strengthValue.stringValue = String(format: "× %.2f", strength.doubleValue)
    }

    private func sectionTitle(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }
}

@MainActor
private final class XDRBooster {
    // 保存开启前的 Gamma 表；关闭时必须用它精确恢复。
    private var gamma: GammaSnapshot?
    // 1×1 Metal 窗口：仅用于请求系统进入 EDR 合成路径。
    private var overlay: HDRTriggerWindow?
    private var monitor: Timer?

    var multiplier: CGFloat = 1.45 {
        // 开启期间调节滑块时，立刻基于原始 Gamma 表重新写入倍率。
        didSet { if isEnabled { applyGamma() } }
    }
    private(set) var isEnabled = false
    private(set) var isSupported = false
    private(set) var displayName = "正在检测显示器"
    private(set) var potentialHeadroom: CGFloat = 1
    private(set) var status = "正在检测显示器能力…"
    private(set) var isHDRReady = false

    init() {
        // 显示器休眠前先恢复，避免恢复桌面后遗留临时 Gamma 设置。
        NotificationCenter.default.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.disable(reason: "显示器休眠，已恢复系统设置") }
        }
        NotificationCenter.default.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func refresh() {
        // 只针对内置且报告 EDR 余量的屏幕；不改动外接显示器。
        guard let screen = targetScreen else {
            isSupported = false
            isHDRReady = false
            displayName = "未找到兼容显示器"
            potentialHeadroom = 1
            if !isEnabled { status = "需要带 XDR/EDR 的内置显示器" }
            return
        }
        displayName = screen.localizedName
        potentialHeadroom = max(screen.maximumPotentialExtendedDynamicRangeColorComponentValue, 1)
        isSupported = potentialHeadroom > 1
        if !isEnabled { status = isSupported ? "准备就绪；由 macOS 管理面板保护" : "此显示器未报告 EDR 余量" }
    }

    func enable() {
        guard !isEnabled, let screen = targetScreen, let id = screen.displayID else { return }
        do {
            // 先保存系统当前 Gamma，再显示 HDR 触发层，最后应用用户选择的倍率。
            gamma = try GammaSnapshot.capture(displayID: id)
            overlay = HDRTriggerWindow(screen: screen)
            isEnabled = true
            applyGamma()
            // EDR 状态可能随系统策略变化，定时重新确认后再写入 Gamma。
            monitor = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.applyGamma() }
            }
            status = "已请求 HDR；系统确认后应用当前强度"
        } catch {
            disable(reason: "无法启用：\(error.localizedDescription)")
        }
    }

    func disable(reason: String = "已恢复系统显示设置") {
        // 关闭顺序很重要：停止轮询、撤下 HDR 层、恢复原 Gamma，最后更新状态。
        monitor?.invalidate(); monitor = nil
        overlay?.close(); overlay = nil
        gamma?.restore(); gamma = nil
        isEnabled = false
        isHDRReady = false
        status = reason
    }

    private func applyGamma() {
        guard isEnabled, let screen = targetScreen else { return }
        let edr = screen.maximumExtendedDynamicRangeColorComponentValue
        // 等待 1×1 HDR 图层让系统自行进入 EDR；这里不直接强制面板开启 HDR。
        guard edr > 1.05 else { isHDRReady = false; status = "正在等待 macOS 启用 HDR…"; return }
        do {
            try gamma?.apply(multiplier: multiplier)
            isHDRReady = true
            status = String(format: "HDR 已就绪（当前 EDR %.2f×）", edr)
        } catch {
            disable(reason: "更新 Gamma 失败，已恢复系统设置")
        }
    }

    private var targetScreen: NSScreen? {
        // 仅选择支持 EDR 的内置显示器。
        NSScreen.screens.first { $0.displayID != nil && $0.isBuiltIn && $0.maximumPotentialExtendedDynamicRangeColorComponentValue > 1 }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        // AppKit 的 NSScreenNumber 转换为 CoreGraphics 所需的显示器 ID。
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
    var isBuiltIn: Bool { displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false }
}

private struct GammaSnapshot {
    // 开启增强前的 RGB Gamma 查找表快照。
    let displayID: CGDirectDisplayID
    let red, green, blue: [CGGammaValue]

    static func capture(displayID: CGDirectDisplayID) throws -> Self {
        // CoreGraphics 最多读取 1024 个采样点；实际数量由 count 返回。
        let capacity: UInt32 = 1024
        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red, blue = red, count: UInt32 = 0
        let result = CGGetDisplayTransferByTable(displayID, capacity, &red, &green, &blue, &count)
        guard result == .success, count > 1 else { throw BoosterError.gammaRead }
        return Self(displayID: displayID, red: Array(red.prefix(Int(count))), green: Array(green.prefix(Int(count))), blue: Array(blue.prefix(Int(count))))
    }

    func apply(multiplier: CGFloat) throws {
        // 限制倍率范围，防止 UI 外部传入过高数值；始终基于原始快照计算，
        // 避免多次拖动造成 Gamma 叠加放大。
        let factor = Float(min(max(multiplier, 1), 1.75))
        let result = CGSetDisplayTransferByTable(displayID, UInt32(red.count), red.map { $0 * factor }, green.map { $0 * factor }, blue.map { $0 * factor })
        guard result == .success else { throw BoosterError.gammaWrite }
    }

    func restore() {
        // 先写回原 Gamma 表，再让 ColorSync 恢复系统色彩设置。
        _ = CGSetDisplayTransferByTable(displayID, UInt32(red.count), red, green, blue)
        CGDisplayRestoreColorSyncSettings()
    }
}

// 这个 1×1 浮点 Metal 图层位于显示器右上角圆角区域内，正常情况下不可见。
// 它唯一的作用是请求 macOS 走常规 HDR/EDR 合成路径，不绘制任何可见界面。
@MainActor
private final class HDRTriggerWindow {
    private let window: NSWindow

    init(screen: NSScreen) {
        // 右上角坐标可避开常见内容区域；窗口不接收鼠标，也不会参与窗口切换。
        window = NSWindow(contentRect: NSRect(x: screen.frame.minX, y: screen.frame.maxY - 1, width: 1, height: 1), styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
        window.contentView = HDRMetalView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        window.orderFrontRegardless()
    }

    func close() { window.orderOut(nil) }
}

private final class HDRMetalView: MTKView, MTKViewDelegate {
    private let queue: MTLCommandQueue

    init(frame: CGRect) {
        let device = MTLCreateSystemDefaultDevice()!
        queue = device.makeCommandQueue()!
        super.init(frame: frame, device: device)
        delegate = self
        // 使用浮点像素格式和扩展线性色彩空间，允许清屏值超过 SDR 的 1.0。
        colorPixelFormat = .rgba16Float
        colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        // 大于 1 的清屏值是请求 EDR 的关键；不代表屏幕会被直接写成该亮度。
        clearColor = MTLClearColorMake(1.6, 1.6, 1.6, 1)
        drawableSize = CGSize(width: 1, height: 1)
        preferredFramesPerSecond = 5
        if let layer = layer as? CAMetalLayer {
            // 明确声明该图层可包含扩展动态范围内容。
            layer.wantsExtendedDynamicRangeContent = true
            layer.pixelFormat = .rgba16Float
        }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func draw(in view: MTKView) {
        // 本图层无需绘制几何体；提交清屏后的 render pass 即可维持 EDR 请求。
        guard let pass = currentRenderPassDescriptor, let drawable = currentDrawable, let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.endEncoding(); buffer.present(drawable); buffer.commit()
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
}

private enum BoosterError: LocalizedError {
    case gammaRead, gammaWrite
    var errorDescription: String? { self == .gammaRead ? "无法读取显示 Gamma 表" : "无法写入显示 Gamma 表" }
}
