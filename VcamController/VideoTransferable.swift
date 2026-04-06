import CoreTransferable
import UniformTypeIdentifiers

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        // "public.movie" cobre TODOS os formatos de vídeo (.mov, .mp4, HEVC, etc.)
        FileRepresentation(contentType: UTType("public.movie")!) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copia direto para o destino final do VCam (sem staging)
            let vcamDir = "/var/jb/var/mobile/Library"
            let dest    = URL(fileURLWithPath: "\(vcamDir)/temp.mov")
            try? FileManager.default.createDirectory(
                atPath: vcamDir, withIntermediateDirectories: true, attributes: nil)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}
