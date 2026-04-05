import SwiftUI

struct RootView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "111113").ignoresSafeArea()

            Group {
                if selectedTab == 0 {
                    HomeView()
                } else {
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 72)

            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Custom Tab Bar (matches screenshot style)
struct CustomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 0) {
            // Thin separator line
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            HStack(spacing: 0) {
                TabBarItem(label: "Home",    tag: 0, selected: $selectedTab)
                TabBarItem(label: "Settings", tag: 1, selected: $selectedTab)
            }
            .frame(height: 72)
            .background(Color(hex: "111113"))
        }
    }
}

struct TabBarItem: View {
    let label: String
    let tag: Int
    @Binding var selected: Int

    private let purple = Color(hex: "BF82F6")

    var body: some View {
        Button {
            selected = tag
        } label: {
            VStack(spacing: 4) {
                // Triangle indicator
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(selected == tag ? purple : Color.clear)

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selected == tag ? purple : Color.gray.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8)  & 0xFF) / 255
            b = Double(int         & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
