import Foundation
import AVFoundation
import UIKit

class VcamManager: ObservableObject {
    static let shared = VcamManager()

    // Rootless jailbreak paths
    let tempMovPath   = "/var/jb/var/mobile/Library/temp.mov"
    let mirrorMarkPath = "/var/jb/var/mobile/Library/vcam_is_mirrored_mark"

    @Published var isEnabled: Bool = false
    @Published var isMirrored: Bool = false
    @Published var videoThumbnail: UIImage? = nil

    private let fm = FileManager.default

    private init() { refresh() }

    func refresh() {
        isEnabled = fm.fileExists(atPath: tempMovPath)
        isMirrored = fm.fileExists(atPath: mirrorMarkPath)
        if isEnabled {
            generateThumbnail(from: URL(fileURLWithPath: tempMovPath))
        } else {
            videoThumbnail = nil
        }
    }

    /// Copy a video from a temp/picker URL into the VCam slot
    func setVideo(from sourceURL: URL) throws {
        let dir = (tempMovPath as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        try? fm.removeItem(atPath: tempMovPath)
        try fm.copyItem(at: sourceURL, to: URL(fileURLWithPath: tempMovPath))
        DispatchQueue.main.async { self.refresh() }
    }

    func clearVideo() {
        try? fm.removeItem(atPath: tempMovPath)
        DispatchQueue.main.async { self.refresh() }
    }

    func setMirror(_ enabled: Bool) {
        if enabled {
            fm.createFile(atPath: mirrorMarkPath, contents: nil, attributes: nil)
        } else {
            try? fm.removeItem(atPath: mirrorMarkPath)
        }
        DispatchQueue.main.async { self.isMirrored = enabled }
    }

    func toggleMirror() {
        setMirror(!isMirrored)
    }

    /// Generate thumbnail for a local video URL and update `videoThumbnail`
    func setPendingThumbnail(from url: URL) {
        generateThumbnail(from: url)
    }

    private func generateThumbnail(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 800, height: 800)
            if let cgImage = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                let image = UIImage(cgImage: cgImage)
                DispatchQueue.main.async { self.videoThumbnail = image }
            }
        }
    }
}
