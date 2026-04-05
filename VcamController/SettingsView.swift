import SwiftUI

struct SettingsView: View {
    @StateObject private var vcam = VcamManager.shared
    @State private var showClearConfirm = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let purple  = Color(hex: "BF82F6")
    private let bgCard  = Color(hex: "1E1E21")

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Status Card ──────────────────────────────────────────
                SettingsCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status VCam")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                            Text(vcam.isEnabled ? "Ativo" : "Inativo")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(vcam.isEnabled ? .green : .red)
                        }
                        Spacer()
                        Circle()
                            .fill(vcam.isEnabled ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                            .shadow(color: vcam.isEnabled ? .green : .red, radius: 4)
                    }
                }

                // ── Mirror Toggle ────────────────────────────────────────
                SettingsCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Modo Espelho")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Espelha o vídeo horizontalmente")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { vcam.isMirrored },
                            set: { vcam.setMirror($0) }
                        ))
                        .tint(purple)
                    }
                }

                // ── File Paths ───────────────────────────────────────────
                SettingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Arquivos do Tweak")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)

                        PathRow(label: "Vídeo", path: vcam.tempMovPath,
                                exists: FileManager.default.fileExists(atPath: vcam.tempMovPath))
                        Divider().background(Color.white.opacity(0.07))
                        PathRow(label: "Mirror Mark", path: vcam.mirrorMarkPath,
                                exists: FileManager.default.fileExists(atPath: vcam.mirrorMarkPath))
                    }
                }

                // ── Danger Zone ──────────────────────────────────────────
                SettingsCard {
                    VStack(spacing: 12) {
                        Text("Danger Zone")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            showClearConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Limpar Vídeo Ativo")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(!vcam.isEnabled)
                        .opacity(vcam.isEnabled ? 1 : 0.4)
                    }
                }

                // ── Version ──────────────────────────────────────────────
                Text("VCam Controller v1.0  •  Rootless Jailbreak")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray.opacity(0.35))
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color(hex: "111113"))
        .confirmationDialog("Limpar vídeo?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Limpar", role: .destructive) {
                vcam.clearVideo()
                alertMessage = "Vídeo removido."
                showAlert = true
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O vídeo virtual será desativado. Você pode selecionar outro a qualquer momento.")
        }
        .alert("VCam", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .onAppear { vcam.refresh() }
    }
}

// MARK: - Settings helpers

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(16)
            .background(Color(hex: "1E1E21"))
            .cornerRadius(14)
    }
}

struct PathRow: View {
    let label: String
    let path: String
    let exists: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            Text(path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(exists ? Color(hex: "BF82F6") : .gray)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer()
            Image(systemName: exists ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(exists ? .green : .red)
                .font(.system(size: 13))
        }
    }
}
