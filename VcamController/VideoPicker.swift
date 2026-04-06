import SwiftUI
import PhotosUI
import AVFoundation

struct VideoPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        // photoLibrary: .shared() permite assetIdentifier no resultado
        var config = PHPickerConfiguration(photoLibrary: .shared())
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
            guard let assetId = results.first?.assetIdentifier else {
                // Sem assetIdentifier = sem permissão — tentar via itemProvider
                if let provider = results.first?.itemProvider {
                    loadViaItemProvider(provider)
                }
                return
            }

            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = assets.firstObject else {
                DispatchQueue.main.async { self.onError("Vídeo não encontrado na biblioteca.") }
                return
            }

            let opts = PHVideoRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.deliveryMode = .highQualityFormat

            // requestExportSession é a API oficial para exportar vídeos da galeria
            PHImageManager.default().requestExportSession(
                forVideo: asset,
                options: opts,
                exportPreset: AVAssetExportPresetPassthrough
            ) { session, _ in
                guard let session = session else {
                    DispatchQueue.main.async { self.onError("Falha ao criar sessão de exportação.") }
                    return
                }
                self.runExport(session)
            }
        }

        private func loadViaItemProvider(_ provider: NSItemProvider) {
            provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                guard let url = url else {
                    DispatchQueue.main.async {
                        self.onError(error?.localizedDescription ?? "Vídeo não disponível.")
                    }
                    return
                }
                let asset = AVURLAsset(url: url)
                guard let session = AVAssetExportSession(asset: asset,
                                                         presetName: AVAssetExportPresetPassthrough) else {
                    DispatchQueue.main.async { self.onError("Sessão de exportação inválida.") }
                    return
                }
                self.runExport(session)
            }
        }

        private func runExport(_ session: AVAssetExportSession) {
            let dest = URL(fileURLWithPath: "/var/mobile/Library/Caches/vcam_export.mov")
            try? FileManager.default.removeItem(at: dest)
            session.outputURL = dest
            session.outputFileType = .mov
            session.exportAsynchronously {
                if session.status == .completed {
                    DispatchQueue.main.async { self.onPicked(dest) }
                } else {
                    let msg = session.error?.localizedDescription ?? "Falha na exportação."
                    DispatchQueue.main.async { self.onError(msg) }
                }
            }
        }
    }
}
