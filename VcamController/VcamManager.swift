import Foundation
import AVFoundation
import UIKit

class VcamManager: ObservableObject {
    static let shared = VcamManager()

    let tempMovPath    = "/var/jb/var/mobile/Library/temp.mov"
    let mirrorMarkPath = "/var/jb/var/mobile/Library/vcam_is_mirrored_mark"

    @Published var isEnabled: Bool  = false
    @Published var isMirrored: Bool = false
    @Published var isFixing: Bool   = false
    @Published var videoThumbnail: UIImage? = nil

    private let fm = FileManager.default

    private init() { refresh() }

    func refresh() {
        isEnabled  = fm.fileExists(atPath: tempMovPath)
        isMirrored = fm.fileExists(atPath: mirrorMarkPath)
        if isEnabled {
            generateThumbnail(from: URL(fileURLWithPath: tempMovPath))
        } else {
            videoThumbnail = nil
        }
    }

    // MARK: - Activate

    /// Copia o vídeo do temp dir para o destino final do VCam
    func installVideo(from sourceURL: URL) throws {
        let dest = URL(fileURLWithPath: tempMovPath)
        let dir  = (tempMovPath as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        try? fm.removeItem(at: dest)
        try fm.copyItem(at: sourceURL, to: dest)
        refresh()
        fixRotationIfNeeded()
    }

    /// Corrige orientação se necessário
    func fixRotationIfNeeded() {
        let dest = URL(fileURLWithPath: tempMovPath)
        guard fm.fileExists(atPath: tempMovPath) else { return }
        let rotation = detectNeededRotation(url: dest)
        guard rotation != 0 else { return }

        isFixing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let tmp = self.fm.temporaryDirectory
                .appendingPathComponent("vcam_fix_\(Int(Date().timeIntervalSince1970)).mov")
            self.exportRotated(sourceURL: dest, outputURL: tmp, degrees: rotation) { error in
                DispatchQueue.main.async {
                    self.isFixing = false
                    if error == nil {
                        try? self.fm.removeItem(at: dest)
                        try? self.fm.moveItem(at: tmp, to: dest)
                    }
                    self.refresh()
                }
            }
        }
    }

    func clearVideo() {
        try? fm.removeItem(atPath: tempMovPath)
        refresh()
    }

    // MARK: - Mirror

    func setMirror(_ enabled: Bool) {
        if enabled {
            fm.createFile(atPath: mirrorMarkPath, contents: nil, attributes: nil)
        } else {
            try? fm.removeItem(atPath: mirrorMarkPath)
        }
        isMirrored = enabled
    }

    func toggleMirror() { setMirror(!isMirrored) }

    // MARK: - Thumbnail

    func setPendingThumbnail(from url: URL) { generateThumbnail(from: url) }

    private func generateThumbnail(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let gen   = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 800, height: 800)
            if let cg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                let img = UIImage(cgImage: cg)
                DispatchQueue.main.async { self.videoThumbnail = img }
            }
        }
    }

    // MARK: - Rotation (portado do VCamAppIOS)

    func detectNeededRotation(url: URL) -> Int {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return 0 }
        let t = track.preferredTransform
        if t.a == 0 && t.b == 1  && t.c == -1 && t.d == 0  { return -90 }
        if t.a == 0 && t.b == -1 && t.c == 1  && t.d == 0  { return  90 }
        if t.a == -1 && t.b == 0 && t.c == 0  && t.d == -1 { return 180 }
        return 0
    }

    func exportRotated(sourceURL: URL, outputURL: URL, degrees: Int, completion: @escaping (Error?) -> Void) {
        let asset = AVURLAsset(url: sourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(NSError(domain: "VCam", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sem faixa de vídeo"]))
            return
        }
        let origTransform = videoTrack.preferredTransform
        let natSize = videoTrack.naturalSize
        let isPortrait = abs(origTransform.b) == 1.0 || abs(origTransform.c) == 1.0
        let curW: CGFloat = isPortrait ? natSize.height : natSize.width
        let curH: CGFloat = isPortrait ? natSize.width  : natSize.height
        let newW: CGFloat = abs(degrees) == 90 ? curH : curW
        let newH: CGFloat = abs(degrees) == 90 ? curW : curH

        let composition = AVMutableComposition()
        guard let compTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(NSError(domain: "VCam", code: 2, userInfo: [NSLocalizedDescriptionKey: "Erro ao criar faixa"]))
            return
        }
        let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        do { try compTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero) }
        catch { completion(error); return }

        if let audio = asset.tracks(withMediaType: .audio).first,
           let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compAudio.insertTimeRange(timeRange, of: audio, at: .zero)
        }

        let rotRad = CGFloat(degrees) * .pi / 180.0
        var rotT   = CGAffineTransform(rotationAngle: rotRad)
        switch degrees {
        case  90:        rotT = rotT.translatedBy(x: 0,     y: -curH)
        case -90:        rotT = rotT.translatedBy(x: -curW, y: 0)
        case 180, -180:  rotT = rotT.translatedBy(x: -curW, y: -curH)
        default: break
        }

        let layerInstr = AVMutableVideoCompositionLayerInstruction(assetTrack: compTrack)
        layerInstr.setTransform(origTransform.concatenating(rotT), at: .zero)

        let instr = AVMutableVideoCompositionInstruction()
        instr.timeRange = timeRange
        instr.layerInstructions = [layerInstr]

        let videoComp = AVMutableVideoComposition()
        videoComp.renderSize = CGSize(width: newW, height: newH)
        videoComp.frameDuration = CMTime(value: 1, timescale: 30)
        videoComp.instructions = [instr]

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(NSError(domain: "VCam", code: 3, userInfo: [NSLocalizedDescriptionKey: "Erro na exportação"]))
            return
        }
        export.outputURL = outputURL
        export.outputFileType = .mov
        export.videoComposition = videoComp
        export.exportAsynchronously { completion(export.status == .completed ? nil : export.error) }
    }
}
