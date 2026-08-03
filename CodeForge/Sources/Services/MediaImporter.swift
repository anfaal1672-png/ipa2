import UIKit
import PhotosUI
import UniformTypeIdentifiers

/// Brings photos, videos and camera captures into the workspace.
///
/// Driven from UIKit rather than through SwiftUI's presentation modifiers, for
/// the same reason `DocumentImporter` is: this screen already carries several
/// sheets, alerts and dialogs, and adding more presentation state to it is how
/// pickers end up showing without ever delivering a result.
///
/// The photo library goes through `PHPickerViewController`, which runs out of
/// process — the app only ever receives the items the user picked, and no photo
/// library permission is involved at all. The camera does need permission, and
/// iOS asks for it on first use.
final class MediaImporter: NSObject {

    static let shared = MediaImporter()

    private var completion: (([URL]) -> Void)?
    private var failure: ((String) -> Void)?

    /// Files are staged here and then copied into the project, so a failure
    /// part-way through cannot leave half an import in the user's folder.
    private static var scratchDirectory: URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("codeforge-import", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Photo library

    func presentLibrary(onError: @escaping (String) -> Void,
                        completion: @escaping ([URL]) -> Void) {
        guard let presenter = DocumentImporter.topViewController() else {
            completion([])
            return
        }
        self.completion = completion
        self.failure = onError

        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 0                 // no limit
        configuration.filter = .any(of: [.images, .videos])
        // The original file, not a re-encoded copy: an asset dropped into a web
        // page should be the bytes the user actually has.
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    // MARK: - Camera

    func presentCamera(onError: @escaping (String) -> Void,
                       completion: @escaping ([URL]) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            onError(L("This device has no camera."))
            completion([])
            return
        }
        guard let presenter = DocumentImporter.topViewController() else {
            completion([])
            return
        }
        self.completion = completion
        self.failure = onError

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    // MARK: - Naming

    /// `photo-20260731-081500.jpg`. Sorts chronologically in the file list and
    /// never collides with the shot taken a second earlier.
    static func captureName(prefix: String, extension ext: String, at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(prefix)-\(formatter.string(from: date)).\(ext)"
    }

    private func finish(_ urls: [URL]) {
        let handler = completion
        completion = nil
        failure = nil
        DispatchQueue.main.async { handler?(urls) }
    }

    private func report(_ message: String) {
        let handler = failure
        DispatchQueue.main.async { handler?(message) }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension MediaImporter: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else {
            finish([])
            return
        }

        let scratch = Self.scratchDirectory
        var staged: [URL] = []
        let lock = NSLock()
        let group = DispatchGroup()

        for result in results {
            let provider = result.itemProvider
            // The first identifier is the item's own type (public.heic,
            // public.jpeg, public.mpeg-4 …); asking for that rather than for a
            // UIImage is what keeps the original bytes.
            guard let identifier = provider.registeredTypeIdentifiers.first else { continue }
            group.enter()
            provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, error in
                defer { group.leave() }
                guard let url else {
                    if let error { self.report(error.localizedDescription) }
                    return
                }
                // The file is deleted the moment this closure returns, so it has
                // to be copied here rather than handed on.
                let name = Self.stagedName(for: provider, fileURL: url)
                let destination = scratch.appendingPathComponent(name)
                try? FileManager.default.removeItem(at: destination)
                do {
                    try FileManager.default.copyItem(at: url, to: destination)
                    lock.lock()
                    staged.append(destination)
                    lock.unlock()
                } catch {
                    self.report(error.localizedDescription)
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.finish(staged)
        }
    }

    /// The name the picker suggests, with the extension the actual file has.
    static func stagedName(for provider: NSItemProvider, fileURL: URL) -> String {
        let ext = fileURL.pathExtension
        guard let suggested = provider.suggestedName, !suggested.isEmpty else {
            return fileURL.lastPathComponent
        }
        if ext.isEmpty { return suggested }
        return (suggested as NSString).pathExtension.isEmpty ? "\(suggested).\(ext)" : suggested
    }
}

// MARK: - UIImagePickerControllerDelegate

extension MediaImporter: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let scratch = Self.scratchDirectory

        if let movie = info[.mediaURL] as? URL {
            let ext = movie.pathExtension.isEmpty ? "mov" : movie.pathExtension
            let destination = scratch.appendingPathComponent(
                Self.captureName(prefix: "video", extension: ext))
            try? FileManager.default.removeItem(at: destination)
            do {
                try FileManager.default.copyItem(at: movie, to: destination)
                finish([destination])
            } catch {
                report(error.localizedDescription)
                finish([])
            }
            return
        }

        // A camera photo arrives as pixels rather than as a file, so it has to
        // be encoded. JPEG at 90% is what every browser and editor can read.
        if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage,
           let data = image.jpegData(compressionQuality: 0.9) {
            let destination = scratch.appendingPathComponent(
                Self.captureName(prefix: "photo", extension: "jpg"))
            do {
                try data.write(to: destination, options: .atomic)
                finish([destination])
            } catch {
                report(error.localizedDescription)
                finish([])
            }
            return
        }

        finish([])
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        finish([])
    }
}
