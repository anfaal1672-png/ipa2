import SwiftUI
import UIKit

/// User-facing editor preferences, persisted in `UserDefaults`.
final class EditorSettings: ObservableObject {

    static let shared = EditorSettings()

    @AppStorage("themeID") var themeID: String = Themes.midnight.id { didSet { objectWillChange.send() } }
    @AppStorage("fontSize") var fontSize: Double = 14 { didSet { objectWillChange.send() } }
    @AppStorage("fontName") var fontName: String = FontChoice.system.rawValue { didSet { objectWillChange.send() } }
    @AppStorage("tabWidth") var tabWidth: Int = 4 { didSet { objectWillChange.send() } }
    @AppStorage("useSpaces") var useSpaces: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("wrapLines") var wrapLines: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("showLineNumbers") var showLineNumbers: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("showInvisibles") var showInvisibles: Bool = false { didSet { objectWillChange.send() } }
    @AppStorage("highlightCurrentLine") var highlightCurrentLine: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("showIndentGuides") var showIndentGuides: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("syntaxHighlighting") var syntaxHighlighting: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("autoIndent") var autoIndent: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("autoCloseBrackets") var autoCloseBrackets: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("showKeyboardToolbar") var showKeyboardToolbar: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("autoSave") var autoSave: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("lineSpacing") var lineSpacing: Double = 2 { didSet { objectWillChange.send() } }
    @AppStorage("followSystemAppearance") var followSystemAppearance: Bool = false { didSet { objectWillChange.send() } }
    @AppStorage("lightThemeID") var lightThemeID: String = Themes.xcodeLight.id { didSet { objectWillChange.send() } }
    @AppStorage("pinchToZoom") var pinchToZoom: Bool = true { didSet { objectWillChange.send() } }
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false { didSet { objectWillChange.send() } }
    @AppStorage("appLanguage") var appLanguageRaw: String = AppLanguage.system.rawValue {
        didSet {
            Localization.shared.language = appLanguage
            objectWillChange.send()
        }
    }

    var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: appLanguageRaw) ?? .system }
        set { appLanguageRaw = newValue.rawValue }
    }

    private init() {
        Localization.shared.language = AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        ) ?? .system
    }

    func resetToDefaults() {
        themeID = Themes.midnight.id
        lightThemeID = Themes.xcodeLight.id
        fontSize = 14
        fontName = FontChoice.system.rawValue
        tabWidth = 4
        useSpaces = true
        wrapLines = true
        showLineNumbers = true
        highlightCurrentLine = true
        showIndentGuides = true
        syntaxHighlighting = true
        autoIndent = true
        autoCloseBrackets = true
        showKeyboardToolbar = true
        autoSave = true
        pinchToZoom = true
        followSystemAppearance = false
    }

    enum FontChoice: String, CaseIterable, Identifiable {
        case system = "System Mono"
        case menlo = "Menlo"
        case courier = "Courier New"
        case sfMonoRounded = "Rounded Mono"

        var id: String { rawValue }

        func font(size: CGFloat) -> UIFont {
            switch self {
            case .system:
                return .monospacedSystemFont(ofSize: size, weight: .regular)
            case .menlo:
                return UIFont(name: "Menlo-Regular", size: size)
                    ?? .monospacedSystemFont(ofSize: size, weight: .regular)
            case .courier:
                return UIFont(name: "CourierNewPSMT", size: size)
                    ?? .monospacedSystemFont(ofSize: size, weight: .regular)
            case .sfMonoRounded:
                let base = UIFont.monospacedSystemFont(ofSize: size, weight: .medium)
                guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
                return UIFont(descriptor: descriptor, size: size)
            }
        }
    }

    var fontChoice: FontChoice { FontChoice(rawValue: fontName) ?? .system }

    func font() -> UIFont { fontChoice.font(size: CGFloat(fontSize)) }

    func theme(for colorScheme: ColorScheme) -> EditorTheme {
        if followSystemAppearance {
            return colorScheme == .dark ? Themes.theme(id: themeID) : Themes.theme(id: lightThemeID)
        }
        return Themes.theme(id: themeID)
    }

    var indentString: String {
        useSpaces ? String(repeating: " ", count: max(1, tabWidth)) : "\t"
    }
}
