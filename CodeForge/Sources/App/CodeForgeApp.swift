import SwiftUI

@main
struct CodeForgeApp: App {

    @StateObject private var workspace = WorkspaceStore()
    @StateObject private var settings = EditorSettings.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workspace)
                .environmentObject(settings)
                .onAppear {
                    if SelfTest.isEnabled { SelfTest.run() }
                }
                .onOpenURL { url in
                    workspace.openExternal(url: url)
                }
                .onChange(of: scenePhase) { phase in
                    // The editor keeps the live text and no longer mirrors it
                    // on a timer, so leaving the app is one of the moments that
                    // has to write it out.
                    if phase != .active { workspace.saveAll() }
                }
        }
    }
}
