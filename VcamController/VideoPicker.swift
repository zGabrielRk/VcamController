import SwiftUI
import PhotosUI
import AVFoundation

struct VideoPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onError: onError)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: (URL) -> Void
        let onError: (String) -> Void

        init(onPicked: @escaping (URL) -> Void, onError: @escaping (String) -> Void) {
            self.onPicked = onPicked
            self.onError = onError
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }

            result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                if let error = error {
                    DispatchQueue.main.async { self.onError(error.localizedDescription) }
                    return
                }
                guard let url = url else {
                    DispatchQueue.main.async { self.onError("Vídeo não encontrado.") }
                    return
                }

                // AVAssetExportSession lê o arquivo via AVFoundation (acesso nativo à galeria)
                // e escreve no destino que controlamos — bypassa restrições de FileManager
                let dest = URL(fileURLWithPath: "/var/mobile/Library/Caches/vcam_export.mov")
                try? FileManager.default.removeItem(at: dest)

                let asset = AVURLAsset(url: url)
                guard let export = AVAssetExportSession(asset: asset,
                                                        presetName: AVAssetExportPresetPassthrough) else {
                    DispatchQueue.main.async { self.onError("Erro ao criar sessão de exportação.") }
                    return
                }
                export.outputURL = dest
                export.outputFileType = .mov

                // Exporta sincronamente dentro do callback (url ainda válida)
                let sema = DispatchSemaphore(value: 0)
                export.exportAsynchronously { sema.signal() }
                sema.wait()

                if export.status == .completed {
                    DispatchQueue.main.async { self.onPicked(dest) }
                } else {
                    let msg = export.error?.localizedDescription ?? "Falha na exportação."
                    DispatchQueue.main.async { self.onError(msg) }
                }
            }
        }
    }
}
