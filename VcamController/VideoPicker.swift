import SwiftUI
import PhotosUI

/// PhotosPicker (SwiftUI nativo) + loadTransferable — o framework gerencia o acesso ao arquivo
struct VideoPickerButton: View {
    @Binding var selectedItem: PhotosPickerItem?
    let label: String

    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .videos,
            photoLibrary: .shared()
        ) {
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Color(hex: "BF82F6"))
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
}
