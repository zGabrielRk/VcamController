import CoreTransferable
import UniformTypeIdentifiers

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        // DataRepresentation entrega os bytes direto — sem URL de arquivo, sem problema de acesso
        DataRepresentation(importedContentType: UTType("public.movie")!) { data in
            let dest = URL(fileURLWithPath: "/var/mobile/Library/Caches/vcam_import.mov")
            try? FileManager.default.removeItem(at: dest)
            try data.write(to: dest, options: .atomic)
            return Self(url: dest)
        }
    }
}
