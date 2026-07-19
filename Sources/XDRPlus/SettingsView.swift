import AppKit
import ServiceManagement
import SwiftUI

// 设置状态集中在此模型中：SwiftUI 负责展示，XDRBooster 继续负责实际亮度操作。
@MainActor
final class SettingsViewModel: ObservableObject {
    private let booster: XDRBooster?
    private let changed: () -> Void

    @Published private(set) var isEnabled = false
    @Published private(set) var isSupported = false
    @Published private(set) var multiplier = 1.45
    @Published private(set) var launchAtLogin = false
    @Published private(set) var enableBoostAtLaunch = false
    @Published private(set) var language = AppLanguage.current
    @Published var errorMessage: String?

    init(booster: XDRBooster, changed: @escaping () -> Void) {
        self.booster = booster
        self.changed = changed
        refresh()
    }

    // 仅供 Xcode Canvas 使用，避免预览时触碰真实显示器 Gamma 设置。
    private init() {
        booster = nil
        changed = {}
        isSupported = true
    }

    static var preview: SettingsViewModel { SettingsViewModel() }

    func refresh() {
        guard let booster else { return }
        booster.refresh()
        isEnabled = booster.isEnabled
        isSupported = booster.isSupported || booster.isEnabled
        multiplier = Double(booster.multiplier)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        enableBoostAtLaunch = UserDefaults.standard.bool(forKey: PreferenceKey.enableBoostAtLaunch)
        language = AppLanguage.current
    }

    func setEnabled(_ enabled: Bool) {
        guard let booster else {
            isEnabled = enabled
            return
        }
        enabled ? booster.enable() : booster.disable()
        changed()
        refresh()
    }

    func setMultiplier(_ value: Double) {
        multiplier = value
        booster?.multiplier = CGFloat(value)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            // 注册失败时回读系统真实状态，避免 SwiftUI 开关与系统状态不一致。
            launchAtLogin = SMAppService.mainApp.status == .enabled
            errorMessage = error.localizedDescription
        }
    }

    func setEnableBoostAtLaunch(_ enabled: Bool) {
        enableBoostAtLaunch = enabled
        UserDefaults.standard.set(enabled, forKey: PreferenceKey.enableBoostAtLaunch)
    }

    func setLanguage(_ language: AppLanguage) {
        AppLanguage.select(language)
        self.language = language
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

// SwiftUI 设置页可直接在 Xcode Canvas 预览；布局采用黑色、紧凑的系统风格。
struct XDRSettingsView: View {
    @ObservedObject var model: SettingsViewModel

    private let githubURL = URL(string: "https://github.com/LHY-1997/XDR-Booster")!
    private let licenseURL = URL(string: "https://github.com/LHY-1997/XDR-Booster/blob/main/LICENSE")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 为透明标题栏中的交通灯预留顶部空间。
            Color.clear.frame(height: 24)

            header
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            sectionDivider

            // 内容区独立滚动，窗口较小时不会挤压底部的固定操作栏。
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    displaySection
                        .padding(.vertical, 16)

                    // 显示与通用改用留白区分，避免在紧凑窗口中出现多余横线。
                    generalSection
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 固定页脚前以 Island 风格渐隐细线收束内容区。
            sectionDivider

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        // 采用紧凑设置窗口基准尺寸；内容过长时仅中间区域滚动。
        .frame(minWidth: 440, minHeight: 420, alignment: .topLeading)
        // 使用略带蓝相的深灰，而不是纯黑，降低大面积黑底的生硬感。
        .background(Color(red: 0.020, green: 0.020, blue: 0.027))
        .preferredColorScheme(.dark)
        .onAppear { model.refresh() }
        .alert(L10n.text("无法更新开机启动", "Unable to update launch at login"), isPresented: errorPresented) {
            Button(L10n.text("好", "OK"), role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("XDR+")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(L10n.text("MacBook Pro XDR 亮度增强", "MacBook Pro XDR Brightness Booster"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 8)

            Text("v\(displayVersion)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.white.opacity(0.06)))
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L10n.text("显示", "Display"))
            settingsToggleRow(
                L10n.text("亮度增强", "Brightness Enhancement"),
                subtitle: L10n.text("提高 SDR 内容的显示亮度。", "Increase the visible brightness of SDR content."),
                isOn: model.isEnabled,
                enabled: model.isSupported || model.isEnabled
            ) {
                model.setEnabled(!model.isEnabled)
            }

            HStack(alignment: .center) {
                optionLabel(
                    L10n.text("强度", "Strength"),
                    subtitle: L10n.text("调整亮度增强的幅度。", "Adjust the amount of brightness enhancement.")
                )
                Spacer()
                Text(String(format: "× %.2f", model.multiplier))
                    .monospacedDigit()
            }
            .font(.system(size: 13))

            Slider(value: multiplierBinding, in: 1.05...1.75)
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L10n.text("通用", "General"))
            settingsToggleRow(
                // 标题保持 Island 的简短命名；应用名称仅在说明中出现。
                L10n.text("登录时启动", "Launch at login"),
                // 使用简短句式，明确说明登录后会打开的应用。
                subtitle: L10n.text("登录系统时打开 XDR+。", "Open XDR+ when you sign in."),
                isOn: model.launchAtLogin
            ) {
                model.setLaunchAtLogin(!model.launchAtLogin)
            }
            settingsToggleRow(
                L10n.text("启动时打开亮度提升", "Enable brightness enhancement at launch"),
                subtitle: L10n.text("启动 XDR+ 时自动开启亮度增强。", "Enable brightness enhancement whenever XDR+ starts."),
                isOn: model.enableBoostAtLaunch
            ) {
                model.setEnableBoostAtLaunch(!model.enableBoostAtLaunch)
            }

            HStack(alignment: .center, spacing: 12) {
                optionLabel(L10n.text("语言", "Language"), subtitle: model.language.subtitle)
                Spacer()
                Picker("", selection: languageSelectionBinding) {
                    // 明确列出三项，避免 Swift 6.2 在 Canvas 泛型 ForEach 上的编译器崩溃。
                    Text(AppLanguage.automatic.menuLabel).tag(AppLanguage.automatic.rawValue)
                    Text(AppLanguage.chinese.menuLabel).tag(AppLanguage.chinese.rawValue)
                    Text(AppLanguage.english.menuLabel).tag(AppLanguage.english.rawValue)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            .padding(.vertical, 1)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            linkButton("GitHub ↗") { model.open(githubURL) }
            linkButton(L10n.text("许可证 ↗", "License ↗")) { model.open(licenseURL) }
            Spacer()
            Button { model.quit() } label: {
                // 小号半粗文字搭配极浅胶囊背景，避免使用系统默认按钮外观。
                Text(L10n.text("退出", "Quit"))
                    .font(.system(size: 11, weight: .semibold))
                    // 使用 55% 白色，避免退出操作过度抢眼。
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.white.opacity(0.07), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var multiplierBinding: Binding<Double> {
        Binding(get: { model.multiplier }, set: { newValue in model.setMultiplier(newValue) })
    }

    // Picker 使用字符串标签以绕开当前 Swift 6.2 对枚举标签的编译器缺陷。
    private var languageSelectionBinding: Binding<String> {
        Binding(
            get: { model.language.rawValue },
            set: { rawValue in
                guard let language = AppLanguage(rawValue: rawValue) else { return }
                model.setLanguage(language)
            }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }

    // 两端渐隐细线让分区自然出现，而不形成生硬边界。
    private var sectionDivider: some View {
        LinearGradient(
            // 纯黑画布会让原始 Island 数值显得过淡，因此小幅提高中心可见度。
            colors: [.clear, .white.opacity(0.10), .white.opacity(0.10), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    // 分区标题使用 10pt、半粗、0.7 字距与 55% 白色。
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(.white.opacity(0.55))
    }

    // 每个开关采用标题在左、Island 风格蓝色滑块在右的统一行结构。
    private func settingsToggleRow(
        _ title: String,
        subtitle: String,
        isOn: Bool,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center) {
            optionLabel(title, subtitle: subtitle)
            Spacer()
            XDRSettingsToggle(isOn: isOn, action: action)
                .opacity(enabled ? 1 : 0.45)
                .allowsHitTesting(enabled)
        }
    }

    // 行项目层级：标题为 13pt、92% 白色；说明为 11pt、55% 白色。
    private func optionLabel(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .tracking(-0.07)
                .foregroundStyle(.white.opacity(0.92))
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // 链接保持低干扰的文字样式，视觉上让位给右下角退出操作。
    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
        }
        .buttonStyle(.plain)
    }

    private var displayVersion: String {
        let rawVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.5"
        return rawVersion.replacingOccurrences(of: "-test", with: "")
    }
}

// 30×17 的钴蓝开关，开启时带蓝色辉光，关闭时为低对比灰色。
private struct XDRSettingsToggle: View {
    let isOn: Bool
    let action: () -> Void

    @State private var hovered = false
    private let cobalt = Color(red: 0 / 255, green: 71 / 255, blue: 171 / 255)

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .strokeBorder(.white.opacity(hovered ? 0.20 : 0.13), lineWidth: 1)
                    .background {
                        Capsule().fill(isOn ? cobalt.opacity(0.32) : .white.opacity(0.07))
                    }
                    .frame(width: 30, height: 17)

                Circle()
                    .fill(isOn ? cobalt : Color.white.opacity(0.5))
                    .frame(width: 13, height: 13)
                    .shadow(color: isOn ? cobalt.opacity(0.85) : .clear, radius: 5)
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .onHover { hovered = $0 }
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isOn)
        .animation(.easeInOut(duration: 0.16), value: hovered)
    }
}

#if DEBUG
// Canvas 使用独立预览状态，因此预览时不会实际启用亮度增强。
struct XDRSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        XDRSettingsView(model: .preview)
            // 预览尺寸与实际窗口一致，方便在 Canvas 中检查固定页脚和滚动区。
            .frame(width: 440, height: 420)
    }
}
#endif
