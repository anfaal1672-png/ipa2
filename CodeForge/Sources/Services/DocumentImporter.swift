import UIKit
import UniformTypeIdentifiers

/// Presents the system file picker and hands back the picked files.
///
/// SwiftUI's `.fileImporter` is a presentation modifier, and this screen
/// already carries a sheet, two alerts and a confirmation dialog — put a file
/// importer among them and the picker shows but its result never arrives, so
/// tapping "Open" appears to do nothing. Driving `UIDocumentPickerViewController`
/// from UIKit keeps the callback out of SwiftUI's presentation bookkeeping.
final class DocumentImporter: NSObject, UIDocumentPickerDelegate {

    static let shared = DocumentImporter()

    private var completion: (([URL]) -> Void)?

    /// `asCopy` makes iOS hand us a copy in our own temporary directory, so
    /// there is no security-scoped resource to juggle and no chance of reading
    /// a file the user has since moved.
    func present(completion: @escaping ([URL]) -> Void) {
        guard let presenter = Self.topViewController() else {
            completion([])
            return
        }
        self.completion = completion

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.shouldShowFileExtensions = true
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        let handler = completion
        completion = nil
        handler?(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        let handler = completion
        completion = nil
        handler?([])
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
