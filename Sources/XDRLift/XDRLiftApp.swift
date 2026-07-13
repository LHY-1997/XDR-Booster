import AppKit
import CoreGraphics
import MetalKit

@main
struct XDRLiftApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let booster = XDRBooster()
    private var statusItem: NSStatusItem?
    private lazy var menuSliderControl = MenuSliderControl { [weak self] value in
        self?.booster.multiplier = value
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        guard let button = item.button else { return }
        button.image = symbol("sun.max")
        button.target = self
        button.action = #selector(showPanel)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func applicationWillTerminate(_ notification: Notification) {
        booster.disable(reason: "已恢复系统显示设置")
    }

    @objc private func showPanel() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            guard let statusItem else { return }
            statusItem.popUpMenu(makeSystemMenu())
            return
        }
        booster.isEnabled ? booster.disable() : booster.enable()
        refreshIcon()
    }

    private func makeSystemMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let toggle = NSMenuItem(title: "亮度增强", action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        toggle.state = booster.isEnabled ? .on : .off
        toggle.isEnabled = booster.isSupported || booster.isEnabled
        menu.addItem(toggle)

        menu.addItem(makeStrengthItem())
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "设置…", action: #selector(openDisplaySettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    private func makeStrengthItem() -> NSMenuItem {
        let item = NSMenuItem()
        // Let the slider's trailing edge define the menu width.
        let width: CGFloat = 176
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 53))
        // When the toggle is on, AppKit reserves a leading checkmark gutter for
        // standard menu items. Mirror that gutter in our custom slider row.
        let textLeading: CGFloat = booster.isEnabled ? 28 : 13
        let sliderLeading: CGFloat = booster.isEnabled ? 30 : 16
        let sliderWidth: CGFloat = 140
        let label = NSTextField(labelWithString: "强度")
        // Standard menu titles begin 16 pt from the content edge. The checkbox
        // indicator lives in its own leading gutter, so this same column works
        // for both the unchecked and checked states.
        label.frame = NSRect(x: textLeading, y: 31, width: 76, height: 16)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        let value = NSTextField(labelWithString: String(format: "× %.2f", booster.multiplier))
        value.frame = NSRect(x: textLeading + 38, y: 31, width: 76, height: 16)
        value.alignment = .left
        value.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let slider = NSSlider(value: booster.multiplier, minValue: 1.05, maxValue: 1.75, target: menuSliderControl, action: #selector(MenuSliderControl.changed(_:)))
        // NSSlider draws its track and thumb slightly beyond its layout frame.
        // Keep an 8 pt trailing safety inset inside the narrow menu.
        slider.frame = NSRect(x: sliderLeading, y: 7, width: sliderWidth, height: 22)
        slider.isContinuous = true
        // Let people choose the next intensity before turning the enhancement on.
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
    }

    @objc private func openDisplaySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")!)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func refreshIcon() {
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
        onChange(CGFloat(sender.doubleValue))
        valueLabel?.stringValue = String(format: "× %.2f", sender.doubleValue)
    }
}

@MainActor
private final class MenuPanelWindow: NSPanel {
    private static let panelSize = NSSize(width: 248, height: 178)

    init(booster: XDRBooster, changed: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovable = false
        contentViewController = StatusPanelController(booster: booster, changed: changed)
    }

    func show(below anchor: CGPoint) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main
        let menuBarBottom = screen?.visibleFrame.maxY ?? anchor.y
        let x = anchor.x - Self.panelSize.width / 2
        // The visible frame ends exactly at the bottom edge of the menu bar.
        let y = menuBarBottom - Self.panelSize.height
        setFrameOrigin(NSPoint(x: x, y: y))
        orderFrontRegardless()
    }
}

@MainActor
private final class StatusPanelController: NSViewController {
    private let booster: XDRBooster
    private let changed: () -> Void
    private let brightnessToggle = NSButton(checkboxWithTitle: "亮度增强", target: nil, action: nil)
    private let strength = NSSlider(value: 1.45, minValue: 1.05, maxValue: 1.75, target: nil, action: nil)
    private let strengthValue = NSTextField(labelWithString: "")
    private var refreshTimer: Timer?

    init(booster: XDRBooster, changed: @escaping () -> Void) {
        self.booster = booster
        self.changed = changed
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let content = NSView()
        let background: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 16
            glass.contentView = content
            background = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .menu
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 16
            effect.layer?.masksToBounds = true
            content.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(content)
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                content.topAnchor.constraint(equalTo: effect.topAnchor),
                content.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
            ])
            background = effect
        }
        view = background

        brightnessToggle.target = self
        brightnessToggle.action = #selector(toggleBoost)
        brightnessToggle.font = .systemFont(ofSize: 13, weight: .medium)
        brightnessToggle.controlSize = .small

        let sliderTitle = NSTextField(labelWithString: "强度")
        sliderTitle.font = .systemFont(ofSize: 13, weight: .medium)
        sliderTitle.textColor = .labelColor
        strengthValue.alignment = .right
        strengthValue.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let sliderHeader = NSStackView(views: [sliderTitle, strengthValue])
        sliderHeader.orientation = .horizontal
        sliderHeader.distribution = .fill
        sliderHeader.addArrangedSubview(NSView())
        strength.target = self
        strength.action = #selector(strengthChanged)
        strength.isContinuous = true
        let strengthStack = NSStackView(views: [sliderHeader, strength])
        strengthStack.orientation = .vertical
        strengthStack.spacing = 4

        let settings = NSButton(title: "设置…", target: self, action: #selector(openDisplaySettings))
        configureMenuButton(settings, action: #selector(openDisplaySettings))
        settings.font = .systemFont(ofSize: 13, weight: .regular)

        let quitButton = NSButton(title: "退出 XDR Lift", target: self, action: #selector(quit))
        configureMenuButton(quitButton, action: #selector(quit))
        quitButton.font = .systemFont(ofSize: 13, weight: .regular)

        let divider = NSBox()
        divider.boxType = .separator
        let root = NSStackView(views: [brightnessToggle, strengthStack, divider, settings, quitButton])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 7
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            brightnessToggle.widthAnchor.constraint(equalTo: root.widthAnchor),
            divider.widthAnchor.constraint(equalTo: root.widthAnchor),
            strengthStack.widthAnchor.constraint(equalTo: root.widthAnchor),
            settings.widthAnchor.constraint(equalTo: root.widthAnchor),
            quitButton.widthAnchor.constraint(equalTo: root.widthAnchor),
            brightnessToggle.heightAnchor.constraint(equalToConstant: 21),
            settings.heightAnchor.constraint(equalToConstant: 21),
            quitButton.heightAnchor.constraint(equalToConstant: 21)
        ])
        updateSliderValue()
        refresh()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc private func strengthChanged() {
        booster.multiplier = CGFloat(strength.doubleValue)
        updateSliderValue()
        refresh()
    }

    @objc private func toggleBoost() {
        booster.isEnabled ? booster.disable() : booster.enable()
        changed()
        refresh()
    }

    @objc private func openDisplaySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")!)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func refresh() {
        booster.refresh()
        brightnessToggle.state = booster.isEnabled ? .on : .off
        brightnessToggle.isEnabled = booster.isSupported || booster.isEnabled
        strength.isEnabled = booster.isEnabled
    }

    private func updateSliderValue() {
        strengthValue.stringValue = String(format: "× %.2f", strength.doubleValue)
    }

    private func label(_ string: String) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.font = .systemFont(ofSize: 12)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func configureMenuButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.isBordered = false
        button.bezelStyle = .inline
        button.alignment = .left
        button.contentTintColor = .labelColor
        button.focusRingType = .none
    }
}

@MainActor
private final class XDRBooster {
    private var gamma: GammaSnapshot?
    private var overlay: HDRTriggerWindow?
    private var monitor: Timer?

    var multiplier: CGFloat = 1.45 {
        didSet { if isEnabled { applyGamma() } }
    }
    private(set) var isEnabled = false
    private(set) var isSupported = false
    private(set) var displayName = "正在检测显示器"
    private(set) var potentialHeadroom: CGFloat = 1
    private(set) var status = "正在检测显示器能力…"
    private(set) var isHDRReady = false

    init() {
        NotificationCenter.default.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.disable(reason: "显示器休眠，已恢复系统设置") }
        }
        NotificationCenter.default.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func refresh() {
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
            gamma = try GammaSnapshot.capture(displayID: id)
            overlay = HDRTriggerWindow(screen: screen)
            isEnabled = true
            applyGamma()
            monitor = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.applyGamma() }
            }
            status = "已请求 HDR；系统确认后应用当前强度"
        } catch {
            disable(reason: "无法启用：\(error.localizedDescription)")
        }
    }

    func disable(reason: String = "已恢复系统显示设置") {
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
        // Wait for the tiny HDR surface to engage EDR; never force the panel itself.
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
        NSScreen.screens.first { $0.displayID != nil && $0.isBuiltIn && $0.maximumPotentialExtendedDynamicRangeColorComponentValue > 1 }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
    var isBuiltIn: Bool { displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false }
}

private struct GammaSnapshot {
    let displayID: CGDirectDisplayID
    let red, green, blue: [CGGammaValue]

    static func capture(displayID: CGDirectDisplayID) throws -> Self {
        let capacity: UInt32 = 1024
        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red, blue = red, count: UInt32 = 0
        let result = CGGetDisplayTransferByTable(displayID, capacity, &red, &green, &blue, &count)
        guard result == .success, count > 1 else { throw BoosterError.gammaRead }
        return Self(displayID: displayID, red: Array(red.prefix(Int(count))), green: Array(green.prefix(Int(count))), blue: Array(blue.prefix(Int(count))))
    }

    func apply(multiplier: CGFloat) throws {
        let factor = Float(min(max(multiplier, 1), 1.75))
        let result = CGSetDisplayTransferByTable(displayID, UInt32(red.count), red.map { $0 * factor }, green.map { $0 * factor }, blue.map { $0 * factor })
        guard result == .success else { throw BoosterError.gammaWrite }
    }

    func restore() {
        _ = CGSetDisplayTransferByTable(displayID, UInt32(red.count), red, green, blue)
        CGDisplayRestoreColorSyncSettings()
    }
}

// The 1×1 floating-point Metal layer is placed behind the display's rounded corner.
// Its only purpose is to make macOS enter its normal HDR/EDR composition path.
@MainActor
private final class HDRTriggerWindow {
    private let window: NSWindow

    init(screen: NSScreen) {
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
        colorPixelFormat = .rgba16Float
        colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        clearColor = MTLClearColorMake(1.6, 1.6, 1.6, 1)
        drawableSize = CGSize(width: 1, height: 1)
        preferredFramesPerSecond = 5
        if let layer = layer as? CAMetalLayer {
            layer.wantsExtendedDynamicRangeContent = true
            layer.pixelFormat = .rgba16Float
        }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func draw(in view: MTKView) {
        guard let pass = currentRenderPassDescriptor, let drawable = currentDrawable, let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.endEncoding(); buffer.present(drawable); buffer.commit()
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
}

private enum BoosterError: LocalizedError {
    case gammaRead, gammaWrite
    var errorDescription: String? { self == .gammaRead ? "无法读取显示 Gamma 表" : "无法写入显示 Gamma 表" }
}
