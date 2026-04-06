import SwiftUI
import PhotosUI
import AVFoundation

struct VideoPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
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
            guard let result = results.first else { return }

            if let assetId = result.assetIdentifier {
                exportViaPhotoLibrary(assetId: assetId)
            } else {
                // limited access — sem assetIdentifier, tentar via itemProvider
                exportViaItemProvider(result.itemProvider)
            }
        }

        // MARK: - Via PHAsset (full/limited access com assetIdentifier)

        private func exportViaPhotoLibrary(assetId: String) {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = assets.firstObject else {
                DispatchQueue.main.async { self.onError("Vídeo não encontrado na biblioteca.") }
                return
            }

            let opts = PHVideoRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, info in
                guard let avAsset = avAsset else {
                    let err = (info?[PHImageErrorKey] as? Error)?.localizedDescription ?? "Falha ao carregar vídeo."
                    DispatchQueue.main.async { self.onError(err) }
                    return
                }
                self.exportAsset(avAsset)
            }
        }

        // MARK: - Via itemProvider (sem assetIdentifier)

        private func exportViaItemProvider(_ provider: NSItemProvider) {
            let typeId = "public.movie"
            guard provider.hasItemConformingToTypeIdentifier(typeId) else {
                DispatchQueue.main.async { self.onError("Formato de vídeo não suportado.") }
                return
            }
            provider.loadFileRepresentation(forTypeIdentifier: typeId) { url, error in
                guard let url = url else {
                    DispatchQueue.main.async {
                        self.onError(error?.localizedDescription ?? "Vídeo não disponível.")
                    }
                    return
                }
                // url válida apenas aqui — criar AVURLAsset e exportar antes de retornar
                let asset = AVURLAsset(url: url)
                self.exportAsset(asset)
            }
        }

        // MARK: - Export

        private func exportAsset(_ asset: AVAsset) {
            // Usa Documents do app — sempre acessível, AVFoundation não restringe
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
            let dest = docs.appendingPathComponent("vcam_export.mov")
            try? FileManager.default.removeItem(at: dest)

            // HighestQuality funciona com todos os formatos (Passthrough pode falhar com HEVC)
            guard let export = AVAssetExportSession(asset: asset,
                                                    presetName: AVAssetExportPresetHighestQuality) else {
                DispatchQueue.main.async { self.onError("Sessão de exportação inválida.") }
                return
            }
            export.outputURL = dest
            export.outputFileType = .mov

            export.exportAsynchronously {
                if export.status == .completed {
                    DispatchQueue.main.async { self.onPicked(dest) }
                } else {
                    let msg = export.error?.localizedDescription ?? "Exportação falhou (status: \(export.status.rawValue))."
                    DispatchQueue.main.async { self.onError(msg) }
                }
            }
        }
    }
}
