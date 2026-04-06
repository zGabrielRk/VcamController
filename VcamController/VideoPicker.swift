import SwiftUI
import PhotosUI

/// PHPickerViewController via UIKit — funciona com .mov, .mp4, HEVC, todos os formatos
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

            // "public.movie" cobre .mov, .mp4, HEVC — todos os vídeos da galeria
            let typeId = "public.movie"
            guard result.itemProvider.hasItemConformingToTypeIdentifier(typeId) else {
                DispatchQueue.main.async {
                    self.onError("Formato de vídeo não suportado.")
                }
                return
            }

            result.itemProvider.loadFileRepresentation(forTypeIdentifier: typeId) { url, error in
                // ⚠️ url só é válida AQUI — copiar sincronamente antes de retornar
                if let error = error {
                    DispatchQueue.main.async { self.onError(error.localizedDescription) }
                    return
                }
                guard let url = url else {
                    DispatchQueue.main.async { self.onError("Não foi possível carregar o vídeo.") }
                    return
                }
                // NSHomeDirectory() dá o caminho real do container sem symlinks
                let dest = URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("tmp/vcam_pending.mov")
                    .resolvingSymlinksInPath()
                do {
                    try? FileManager.default.removeItem(at: dest)
                    // Cria o diretório tmp se não existir
                    try? FileManager.default.createDirectory(
                        at: dest.deletingLastPathComponent(),
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    try FileManager.default.copyItem(at: url, to: dest)
                    DispatchQueue.main.async { self.onPicked(dest) }
                } catch {
                    DispatchQueue.main.async { self.onError(error.localizedDescription) }
                }
            }
        }
    }
}
