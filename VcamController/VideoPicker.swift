import SwiftUI
import AVFoundation
import MobileCoreServices

/// Usa UIImagePickerController com AVAssetExportPresetPassthrough
/// — mesmo fluxo do tweak vcamrootless.dylib
struct VideoPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.allowsEditing = false
        picker.videoExportPreset = AVAssetExportPresetPassthrough
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

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)

            guard let mediaURL = info[.mediaURL] as? URL else {
                DispatchQueue.main.async { self.onError("URL do vídeo não encontrada.") }
                return
            }

            // mediaURL é path temporário acessível — copiar para nosso tmp canônico
            let dest = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("vcam_export.mov")
            do {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: mediaURL, to: dest)
                DispatchQueue.main.async { self.onPicked(dest) }
            } catch {
                DispatchQueue.main.async { self.onError("Erro ao copiar vídeo: \(error.localizedDescription)") }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
