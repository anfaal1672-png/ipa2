import SwiftUI

@main
struct CodeForgeApp: App {

    @StateObject private var workspace = WorkspaceStore()
    @StateObject private var settings = EditorSettings.shared

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
        }
    }
}
