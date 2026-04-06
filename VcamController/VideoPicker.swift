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
            // AVAssetExportSession só aceita paths no container do processo
            // NSTemporaryDirectory() é garantido acessível para AVFoundation
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("vcam_export.mov")
            try? FileManager.default.removeItem(at: tmp)

            guard let export = AVAssetExportSession(asset: asset,
                                                    presetName: AVAssetExportPresetHighestQuality) else {
                DispatchQueue.main.async { self.onError("Sessão de exportação inválida.") }
                return
            }
            export.outputURL = tmp
            export.outputFileType = .mov

            export.exportAsynchronously {
                guard export.status == .completed else {
                    let msg = export.error?.localizedDescription ?? "Exportação falhou (status \(export.status.rawValue))."
                    DispatchQueue.main.async { self.onError(msg) }
                    return
                }
                // Verifica se o arquivo foi realmente criado
                let exists = FileManager.default.fileExists(atPath: tmp.path)
                guard exists else {
                    DispatchQueue.main.async {
                        self.onError("Export OK mas arquivo não criado.\nPath: \(tmp.path)")
                    }
                    return
                }
                DispatchQueue.main.async { self.onPicked(tmp) }
            }
        }
    }
}
