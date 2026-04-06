import SwiftUI
import UIKit
import MobileCoreServices

/// UIImagePickerController — runs in-process, mediaURL is always a direct file URL
struct VideoPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.videoQuality = .typeHigh
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onError: onError)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (URL) -> Void
        let onError: (String) -> Void

        init(onPicked: @escaping (URL) -> Void, onError: @escaping (String) -> Void) {
            self.onPicked = onPicked
            self.onError = onError
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)

            guard let sourceURL = info[.mediaURL] as? URL else {
                DispatchQueue.main.async { self.onError("Não foi possível obter o vídeo.") }
                return
            }

            // Copy to vcam dir (guaranteed writable, same dir as temp.mov)
            let vcamDir = "/var/jb/var/mobile/Library"
            let dest    = URL(fileURLWithPath: "\(vcamDir)/vcam_staging.mov")

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try? FileManager.default.createDirectory(
                        atPath: vcamDir,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    try? FileManager.default.removeItem(at: dest)
                    try FileManager.default.copyItem(at: sourceURL, to: dest)
                    DispatchQueue.main.async { self.onPicked(dest) }
                } catch {
                    DispatchQueue.main.async { self.onError(error.localizedDescription) }
                }
            }
        }
    }
}
