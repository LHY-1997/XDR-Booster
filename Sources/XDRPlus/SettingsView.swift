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

// SwiftUI 设置页可直接在 Xcode Canvas 预览；布局沿用此前黑色、紧凑的 CodexIsland 风格。
struct XDRSettingsView: View {
    @ObservedObject var model: SettingsViewModel

    private let githubURL = URL(string: "https://github.com/LHY-1997/XDR-Booster")!
    private let licenseURL = URL(string: "https://github.com/LHY-1997/XDR-Booster/blob/main/LICENSE")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 为透明标题栏中的交通灯预留顶部空间。
            Color.clear.frame(height: 24)

            header
                .padding(.bottom, 16)

            sectionDivider

            displaySection
                .padding(.vertical, 16)

            sectionDivider

            generalSection
                .padding(.vertical, 16)

            // 通用区与底部操作也用相同横线收束，形成连续的分区节奏。
            sectionDivider

            footer
                .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(minWidth: 400, minHeight: 400, alignment: .topLeading)
        .background(Color.black)
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
            Toggle(L10n.text("亮度增强", "Brightness Enhancement"), isOn: enabledBinding)
                .toggleStyle(.checkbox)
                .disabled(!model.isSupported && !model.isEnabled)

            HStack {
                Text(L10n.text("强度", "Strength"))
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
            Toggle(L10n.text("开机时启动 XDR+", "Launch XDR+ at login"), isOn: launchAtLoginBinding)
                .toggleStyle(.checkbox)
            Toggle(L10n.text("启动时打开亮度提升", "Enable brightness enhancement at launch"), isOn: enableBoostAtLaunchBinding)
                .toggleStyle(.checkbox)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("语言", "Language"))
                        .font(.system(size: 13, weight: .medium))
                    Text(model.language.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
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
                // 参考 CodexIsland：小号半粗文字搭配极浅胶囊背景，而非系统默认按钮。
                Text(L10n.text("退出", "Quit"))
                    .font(.system(size: 11, weight: .semibold))
                    // 默认使用 CodexIsland 页脚同级的 55% 白色，避免退出操作过度抢眼。
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

    private var enabledBinding: Binding<Bool> {
        Binding(get: { model.isEnabled }, set: { newValue in model.setEnabled(newValue) })
    }

    private var multiplierBinding: Binding<Double> {
        Binding(get: { model.multiplier }, set: { newValue in model.setMultiplier(newValue) })
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { model.launchAtLogin }, set: { newValue in model.setLaunchAtLogin(newValue) })
    }

    private var enableBoostAtLaunchBinding: Binding<Bool> {
        Binding(get: { model.enableBoostAtLaunch }, set: { newValue in model.setEnableBoostAtLaunch(newValue) })
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

    // 复用 CodexIsland 的两端渐隐细线，让分区自然出现而不形成生硬边界。
    private var sectionDivider: some View {
        LinearGradient(
            // 纯黑画布会让原始 Island 数值显得过淡，因此小幅提高中心可见度。
            colors: [.clear, .white.opacity(0.10), .white.opacity(0.10), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    // 章节标题与 CodexIsland 一样使用较小但更重的文字，避免和控件标题竞争层级。
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
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

#if DEBUG
// Canvas 使用独立预览状态，因此预览时不会实际启用亮度增强。
struct XDRSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        XDRSettingsView(model: .preview)
            .frame(width: 400, height: 440)
    }
}
#endif
