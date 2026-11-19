import SwiftUI

struct AppearanceScreen: View {
    @EnvironmentObject var session: ShopSession
    @Environment(\.presentationMode) private var presentation
    @State private var selected: String
    @State private var service = "Cắt tóc"
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 17
    let onApply: (String?) -> Void

    init(initial: String, onApply: @escaping (String?) -> Void) {
        _selected = State(initialValue: initial)
        self.onApply = onApply
    }

    var body: some View {
        let theme = ThemePresets.resolve(personal: selected)
        let spacing = CGFloat(theme.spacing)
        return ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                Button("Quay lại") { presentation.wrappedValue.dismiss() }
                    .frame(minHeight: 44)
                ShopWindowHeading(title: "Bộ giao diện",
                    subtitle: "Mặc định của tiệm · \(ThemePresets.resolve(shop: session.shopPreset).name)")
                Picker("Chọn bộ", selection: $selected) {
                    ForEach(ThemePresets.all, id: \.id) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }.pickerStyle(MenuPickerStyle()).frame(minHeight: 44)
                HStack(spacing: 8) {
                    ForEach([theme.background.argb, theme.surface.argb, theme.action.argb], id: \.self) { color in
                        Circle().fill(Color(argb: color))
                            .overlay(Circle().strokeBorder(Color(argb: theme.muted.argb)))
                            .frame(width: 22, height: 22)
                    }
                }.accessibilityHidden(true)
                Text("Xem trước").font(.headline).accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: spacing) {
                    VStack(alignment: .leading, spacing: spacing) {
                        Text("Khách mẫu · Minh").bold()
                        Text("Đang thực hiện").padding(8)
                            .foregroundColor(Color(argb: 0xFF163F73))
                            .background(Color(argb: 0xFFDEEBFC)).cornerRadius(8)
                        TextField("Dịch vụ mẫu", text: $service).textFieldStyle(RoundedBorderTextFieldStyle())
                            .environment(\.colorScheme, .light).foregroundColor(.black)
                        Text("Xác nhận đơn").foregroundColor(.white).frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color(argb: theme.action.argb)).cornerRadius(8)
                        Button(action: {}) { Label("Thu tiền · Đang khóa", systemImage: "lock.fill") }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundColor(.black).background(Color(argb: 0xFFDEE3E9))
                            .cornerRadius(8).disabled(true)
                    }
                    .padding(spacing).background(Color(argb: theme.surface.argb)).cornerRadius(14)
                    .foregroundColor(Color(argb: theme.ink.argb)).font(.system(size: bodySize * CGFloat(theme.fontScale)))
                }.padding(spacing).background(Color(argb: theme.background.argb)).cornerRadius(14)
                    .accentColor(Color(argb: theme.focus.argb))
                Button("Áp dụng trên thiết bị") { onApply(selected) }.frame(minHeight: 44)
                Button("Dùng mặc định của tiệm") { onApply(nil) }.frame(minHeight: 44)
                if session.profile?.role == "OWNER" {
                    Button("Đặt làm mặc định của tiệm") { session.saveAppearance(selected) }
                        .frame(minHeight: 44).disabled(session.busy)
                }
                if let error = session.error { Text(error) }
            }.padding()
        }
        .onAppear { session.loadAppearance() }
    }
}
