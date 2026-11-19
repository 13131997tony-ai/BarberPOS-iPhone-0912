import Foundation

struct ThemeColor: Decodable {
    let argb: Int64

    init(_ rgb: Int64) {
        argb = rgb | 0xFF000000
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        let hex = try value.decode(String.self)
        guard hex.count == 7, hex.hasPrefix("#"),
              let rgb = Int64(hex.dropFirst(), radix: 16), rgb >= 0 else {
            throw DecodingError.dataCorruptedError(in: value, debugDescription: "Expected a #RRGGBB color.")
        }
        self.init(rgb)
    }
}

struct ThemePreset: Decodable, Identifiable {
    let id: String
    let name: String
    let background: ThemeColor
    let surface: ThemeColor
    let ink: ThemeColor
    let muted: ThemeColor
    let action: ThemeColor
    let focus: ThemeColor
    let fontScale: Double
    let spacing: Int
    let dark: Bool
}

enum ThemePresets {
    static let graphite = ThemePreset(
        id: "GRAPHITE_RED", name: "Graphite đỏ son",
        background: ThemeColor(0x14181E), surface: ThemeColor(0x202631),
        ink: ThemeColor(0xF4F6FA), muted: ThemeColor(0xB5C0CF),
        action: ThemeColor(0xB9362D), focus: ThemeColor(0x88B5FE),
        fontScale: 1, spacing: 12, dark: true
    )
    static let all = load() ?? [graphite]

    static func load(from bundle: Bundle = .main) -> [ThemePreset]? {
        guard let url = bundle.url(forResource: "theme-presets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let presets = try? JSONDecoder().decode([ThemePreset].self, from: data),
              presets.first?.id == graphite.id,
              Set(presets.map(\.id)).count == presets.count else { return nil }
        return presets
    }

    static func resolve(personal: String? = nil, shop: String? = nil) -> ThemePreset {
        all.first { $0.id == personal } ?? all.first { $0.id == shop } ?? graphite
    }
}
