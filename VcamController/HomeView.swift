import SwiftUI
import AVKit

struct HomeView: View {
    @StateObject private var vcam = VcamManager.shared

    @State private var showPicker   = false
    @State private var showPreview  = false
    @State private var showAlert    = false
    @State private var alertMessage = ""
    @State private var isLoading    = false

    private let purple = Color(hex: "BF82F6")
    private let bgCard = Color(hex: "1E1E21")

    var body: some View {
        VStack(spacing: 12) {

            // ── Preview Card ─────────────────────────────────────────
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(bgCard)

                if isLoading || vcam.isFixing {
                    VStack(spacing: 12) {
                        ProgressView().tint(purple).scaleEffect(1.4)
                        Text(vcam.isFixing ? "Corrigindo orientação..." : "Aplicando vídeo...")
                            .foregroundColor(.gray).font(.system(size: 14))
                    }
                } else if let thumb = vcam.videoThumbnail {
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

                if vcam.isEnabled && !isLoading {
                    VStack {
                        HStack {
                            Spacer()
                            Badge(text: "ATIVO", color: .green)
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // ── Buttons ───────────────────────────────────────────────
            VStack(spacing: 10) {

                HStack(spacing: 10) {
                    Button { showPicker = true } label: {
                        PurpleButton(title: "Select")
                    }

                    Button { openPreview() } label: {
                        PurpleButton(title: "Preview")
                    }
                    .opacity(vcam.isEnabled ? 1 : 0.45)
                    .disabled(!vcam.isEnabled)
                }

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
        .sheet(isPresented: $showPicker) {
            VideoPicker(
                onPicked: { exportedURL in
                    isLoading = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try vcam.installVideo(from: exportedURL)
                            DispatchQueue.main.async { isLoading = false }
                        } catch {
                            DispatchQueue.main.async {
                                isLoading = false
                                alertMessage = "Erro ao salvar: \(error.localizedDescription)"
                                showAlert = true
                            }
                        }
                    }
                },
                onError: { msg in
                    isLoading = false
                    alertMessage = "Erro: \(msg)"
                    showAlert = true
                }
            )
        }
        .sheet(isPresented: $showPreview) {
            if vcam.isEnabled {
                VideoPlayer(player: AVPlayer(url: URL(fileURLWithPath: vcam.tempMovPath)))
                    .ignoresSafeArea()
            }
        }
        .alert("VCam", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .onAppear { vcam.refresh() }
    }

    private func openPreview() {
        if vcam.isEnabled { showPreview = true }
    }

    private func disableVcam() {
        vcam.clearVideo()
        alertMessage = "VCam desativado."
        showAlert = true
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
