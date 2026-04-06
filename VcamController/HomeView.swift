import SwiftUI
import AVKit
import PhotosUI

struct HomeView: View {
    @StateObject private var vcam = VcamManager.shared

    @State private var selectedItem:    PhotosPickerItem? = nil
    @State private var pendingURL:      URL?       = nil
    @State private var pendingThumbnail: UIImage?  = nil
    @State private var showPreview      = false
    @State private var previewURL:      URL?       = nil
    @State private var showAlert        = false
    @State private var alertMessage     = ""
    @State private var isLoading        = false
    @State private var isApplying       = false

    private let purple = Color(hex: "BF82F6")
    private let bgCard = Color(hex: "1E1E21")

    var body: some View {
        VStack(spacing: 12) {

            // ── Preview Card ────────────────────────────────────────────
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(bgCard)

                if isLoading || vcam.isFixing {
                    VStack(spacing: 12) {
                        ProgressView().tint(purple).scaleEffect(1.4)
                        Text(vcam.isFixing ? "Corrigindo orientação..." : "Carregando...")
                            .foregroundColor(.gray).font(.system(size: 14))
                    }
                } else if let thumb = pendingThumbnail ?? vcam.videoThumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 38))
                            .foregroundColor(Color.gray.opacity(0.3))
                        Text("Preview do Video")
                            .foregroundColor(Color.gray.opacity(0.4))
                            .font(.system(size: 15))
                    }
                }

                // Badges
                VStack {
                    HStack {
                        Spacer()
                        if vcam.isEnabled && pendingURL == nil {
                            Badge(text: "ATIVO", color: .green)
                        } else if pendingURL != nil {
                            Badge(text: "PENDENTE", color: purple)
                        }
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // ── Buttons ─────────────────────────────────────────────────
            VStack(spacing: 10) {

                HStack(spacing: 10) {
                    // Select — PhotosPicker nativo (framework gerencia acesso ao arquivo)
                    VideoPickerButton(selectedItem: $selectedItem, label: "Select")
                        .onChange(of: selectedItem) { item in
                            guard let item else { return }
                            loadVideo(from: item)
                        }

                    // Preview
                    Button { openPreview() } label: {
                        PurpleButton(title: "Preview")
                    }
                    .opacity((pendingURL != nil || vcam.isEnabled) ? 1 : 0.45)
                    .disabled(pendingURL == nil && !vcam.isEnabled)
                }

                // Apply
                Button { applyVideo() } label: {
                    ZStack {
                        PurpleButton(title: "Apply").opacity(isApplying ? 0 : 1)
                        if isApplying {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Aplicando...")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(purple).cornerRadius(12)
                        }
                    }
                }
                .disabled(isApplying || pendingURL == nil)
                .opacity((pendingURL != nil && !isApplying) ? 1 : 0.45)

                // Disable — só quando ativo
                if vcam.isEnabled {
                    Button { disableVcam() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "video.slash.fill")
                            Text("Disable VCam").font(.system(size: 18, weight: .bold))
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Color.red.opacity(0.18))
                        .foregroundColor(.red).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.35), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Color(hex: "111113"))
        .sheet(isPresented: $showPreview) {
            if let url = previewURL {
                VideoPlayer(player: AVPlayer(url: url)).ignoresSafeArea()
            }
        }
        .alert("VCam", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .onAppear { vcam.refresh() }
    }

    // MARK: - Actions

    private func loadVideo(from item: PhotosPickerItem) {
        isLoading = true
        pendingURL = nil
        pendingThumbnail = nil
        item.loadTransferable(type: VideoTransferable.self) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let video):
                    if let url = video?.url {
                        pendingURL = url
                        generateLocalThumb(from: url)
                    } else {
                        alertMessage = "Erro: não foi possível carregar o vídeo."
                        showAlert = true
                    }
                case .failure(let error):
                    alertMessage = "Erro: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }

    private func generateLocalThumb(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let gen   = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 800, height: 800)
            if let cg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                DispatchQueue.main.async { pendingThumbnail = UIImage(cgImage: cg) }
            }
        }
    }

    private func openPreview() {
        previewURL = pendingURL ?? (vcam.isEnabled ? URL(fileURLWithPath: vcam.tempMovPath) : nil)
        if previewURL != nil { showPreview = true }
    }

    private func disableVcam() {
        vcam.clearVideo()
        pendingURL = nil
        pendingThumbnail = nil
        alertMessage = "🔴 VCam desativado."
        showAlert = true
    }

    private func applyVideo() {
        guard let url = pendingURL else { return }
        isApplying = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try vcam.setVideo(from: url)
                DispatchQueue.main.async {
                    isApplying = false
                    pendingURL = nil
                    pendingThumbnail = nil
                    alertMessage = "✅ Vídeo aplicado! Abra qualquer app de câmera."
                    showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    isApplying = false
                    alertMessage = "❌ Erro: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Helpers

struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.85))
            .cornerRadius(6).padding(10)
    }
}

struct PurpleButton: View {
    let title: String
    private let purple = Color(hex: "BF82F6")
    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(purple).foregroundColor(.white).cornerRadius(12)
    }
}
