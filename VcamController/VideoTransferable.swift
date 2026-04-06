import CoreTransferable
import UniformTypeIdentifiers

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        // "public.movie" cobre TODOS os formatos (.mov, .mp4, HEVC, etc.)
        FileRepresentation(contentType: UTType("public.movie")!) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // /var/mobile/Library/Caches/ é owned by mobile — sempre acessível com no-sandbox
            let dest = URL(fileURLWithPath: "/var/mobile/Library/Caches/vcam_import.mov")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}
