import CoreTransferable
import UniformTypeIdentifiers

private let vcamDir     = "/var/jb/var/mobile/Library"
private let stagingPath = "\(vcamDir)/vcam_staging.mov"

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        // .movie  = com.apple.quicktime-movie (.mov, HEVC, H.264 — câmera do iPhone)
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            try copyToStaging(received.file)
        }
        // .mpeg4Movie = public.mpeg-4 (.mp4)
        FileRepresentation(contentType: .mpeg4Movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            try copyToStaging(received.file)
        }
    }
}

private func copyToStaging(_ source: URL) throws -> VideoTransferable {
    let dest = URL(fileURLWithPath: stagingPath)
    try? FileManager.default.createDirectory(
        atPath: vcamDir,
        withIntermediateDirectories: true,
        attributes: nil
    )
    try? FileManager.default.removeItem(at: dest)
    try FileManager.default.copyItem(at: source, to: dest)
    return VideoTransferable(url: dest)
}
