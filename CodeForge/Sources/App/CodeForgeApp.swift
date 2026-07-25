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
                .onOpenURL { url in
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    workspace.open(url: url)
                }
        }
    }
}
