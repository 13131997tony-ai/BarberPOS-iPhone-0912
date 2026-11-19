import SwiftUI

@main
struct BarberPOSApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate
    @StateObject private var session = ShopSession()
    var body: some Scene {
        WindowGroup { RootScreen().environmentObject(session) }
    }
}

struct RootScreen: View {
    @EnvironmentObject var session: ShopSession
    @State private var username = ""
    @State private var password = ""
    @State private var personalPreset: String?
    private enum Panel: String, Identifiable {
        case appearance, timers, services, operations, doing, waiting, approvals
        var id: String { rawValue }
    }
    @State private var panel: Panel?
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 17
    private var theme: ThemePreset { ThemePresets.resolve(personal: personalPreset, shop: session.shopPreset) }
    private var appearanceKey: String? { session.profile.map { "barberpos.preset." + $0.username } }
    var body: some View {
        NavigationView {
            ZStack {
                Color(argb: theme.background.argb).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: CGFloat(theme.spacing)) {
                        if let profile = session.profile {
                            BrandedShopHeading(title: "Hôm nay", subtitle: profile.name)
                            ShopWindowHeading(title: "Phục vụ khách")
                            Button("Mở nghiệp vụ của tiệm") { panel = .operations }
                            Button("Menu dịch vụ") { panel = .services }
                            Button("Hẹn giờ hóa chất") { panel = .timers }
                            Divider()
                            if profile.role != "BARBER" {
                                Text("Tổng quan tiệm").font(.headline)
                                if session.overviewLoading {
                                    ProgressView("Đang tải tổng quan…")
                                } else if session.overviewFailed {
                                    Text("Không tải được tổng quan.")
                                } else if let overview = profile.overview {
                                    if let orders = overview.orders {
                                        Button("Đang làm · \(orders.doing)") { panel = .doing }
                                        Button("Chờ thu · \(orders.waiting)") { panel = .waiting }
                                    } else {
                                        Text("Đang làm và chờ thu · Không có quyền xem đơn")
                                    }
                                    Button("Chờ duyệt · \(overview.pending)") { panel = .approvals }
                                    Text("\(overview.reviewable) việc bạn có quyền xử lý").font(.caption)
                                } else {
                                    Text("Máy chủ chưa cung cấp tổng quan.")
                                }
                                Button(session.overviewFailed ? "Thử lại" : "Làm mới tổng quan") {
                                    session.refreshOverview()
                                }.disabled(session.overviewLoading)
                            }
                            ShopWindowHeading(title: "Đơn bạn được phép xem")
                            if session.orders.isEmpty {
                                Text("Chưa có đơn.").font(.subheadline)
                            }
                            Button("Tải lại danh sách đơn") { session.loadOrders() }
                            ForEach(session.orders) { order in
                                DisclosureGroup {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(order.lines.enumerated()), id: \.offset) { _, line in
                                            Text("\(line.serviceName) · \(line.performerName)")
                                        }
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(order.customerLabel ?? "Khách vãng lai").bold()
                                        Text(order.statusLabel).font(.subheadline)
                                        if let first = order.lines.first {
                                            Text("\(first.serviceName) · \(order.lines.count) dịch vụ").lineLimit(1)
                                            Text("\(first.performerName) · \(order.createdAt)").font(.caption).lineLimit(2)
                                        }
                                    }
                                }
                                .padding().frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(argb: theme.surface.argb)).cornerRadius(14)
                            }
                            Divider()
                            ShopWindowHeading(title: "Tài khoản & thiết bị")
                            Button("Bộ giao diện") { panel = .appearance }
                            Link("Mở nghiệp vụ đầy đủ trên web", destination: URL(string: "https://app.barberpos-tiem.win")!)
                            Button("Đăng xuất") { session.logout() }.disabled(session.busy)
                        } else {
                            BrandedShopHeading(title: "Đăng nhập", subtitle: "SÓI BARBERSHOP")
                            VStack(spacing: CGFloat(theme.spacing)) {
                                TextField("Tài khoản", text: $username).textContentType(.username).autocapitalization(.none)
                                    .modifier(LoginFieldSurface())
                                SecureField("Mật khẩu", text: $password).textContentType(.password)
                                    .modifier(LoginFieldSurface())
                            }
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(Color(red: 0.09, green: 0.13, blue: 0.17))
                            .accentColor(Color(red: 0.09, green: 0.13, blue: 0.17))
                            .environment(\.colorScheme, .light)
                            Button(session.busy ? "Đang đăng nhập…" : "Đăng nhập") {
                                let entered = password; password = ""
                                session.login(username: username, password: entered)
                            }
                            .buttonStyle(ShopActionStyle(theme: theme, prominent: true))
                            .disabled(session.busy || username.isEmpty || password.isEmpty)
                        }
                        if let error = session.error { Text(error).foregroundColor(.white).padding().background(Color(red:0.45, green:0.1, blue:0.1)).cornerRadius(8) }
                    }
                    .foregroundColor(Color(argb: theme.ink.argb)).font(.system(size: bodySize * CGFloat(theme.fontScale)))
                    .buttonStyle(ShopActionStyle(theme: theme))
                    .padding(CGFloat(theme.spacing))
                    .background(Color(argb: theme.surface.argb)).cornerRadius(14).padding()
                }
            }
            .navigationBarHidden(true)
        }.navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color(argb: theme.focus.argb))
        .preferredColorScheme(theme.dark ? .dark : .light)
        .onChange(of: appearanceKey) { key in
            personalPreset = key.flatMap { UserDefaults.standard.string(forKey: $0) }
        }
        .sheet(item: $panel, onDismiss: { session.refreshOverview() }) { panel in
            switch panel {
            case .operations:
                ShopWebScreen(theme: theme)
            case .doing:
                ShopWebScreen(theme: theme, destination: .doing)
            case .waiting:
                ShopWebScreen(theme: theme, destination: .waiting)
            case .approvals:
                ShopWebScreen(theme: theme, destination: .approvals)
            case .appearance:
                AppearanceScreen(initial: theme.id, onApply: { id in
                    guard let key = appearanceKey else { return }
                    if let id = id { UserDefaults.standard.set(id, forKey: key) }
                    else { UserDefaults.standard.removeObject(forKey: key) }
                    personalPreset = id
                }).environmentObject(session)
            case .services:
                ServiceMenu(theme: theme).environmentObject(session)
            case .timers:
                if let profile = session.profile { TimerScreen(owner: profile.username, theme: theme) }
            }
        }
    }
}

private struct ServiceMenu: View {
    let theme: ThemePreset
    @EnvironmentObject private var session: ShopSession
    @Environment(\.presentationMode) private var presentation
    @State private var category: String?
    @State private var query = ""
    private var current: ShopService? {
        session.services.first { category != nil && $0.categoryID == category }
    }
    private var visible: [ShopService] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty {
            return session.services.filter { service in
                let group = service.categoryName ?? ""
                return (service.name + " " + group).range(of: term,
                    options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
        if let id = current?.categoryID { return session.services.filter { $0.categoryID == id } }
        var seen = Set<String>()
        return session.services.filter { service in
            guard let id = service.categoryID else { return true }
            return seen.insert(id).inserted
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 8) {
                ShopWindowHeading(title: current?.categoryName ?? "Menu dịch vụ")
                TextField("Tìm dịch vụ hoặc nhóm", text: $query).textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Đóng") { presentation.wrappedValue.dismiss() }.frame(minHeight: 44)
                if current != nil { Button("Tất cả nhóm") { category = nil } }
            }.padding()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(visible) { service in
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           current == nil, let id = service.categoryID, let name = service.categoryName {
                            Button(name + " ›") { category = id }
                                .buttonStyle(ShopActionStyle(theme: theme))
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(service.name).font(.headline)
                                Text(NumberFormatter.localizedString(from: NSNumber(value: service.price), number: .decimal) + " đ")
                                    .font(.subheadline).monospacedDigit()
                                    .foregroundColor(Color(argb: theme.muted.argb))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(argb: theme.surface.argb)).cornerRadius(12)
                        }
                    }
                }.padding(.horizontal)
            }
            if visible.isEmpty { Text("Không có dịch vụ phù hợp.").padding() }
            Button("Tải lại") { session.loadOrders() }.padding()
            if let error = session.error { Text(error).padding() }
        }
        .foregroundColor(Color(argb: theme.ink.argb))
        .accentColor(Color(argb: theme.focus.argb))
        .background(Color(argb: theme.background.argb).ignoresSafeArea())
    }
}

private struct LoginFieldSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.white)
            .cornerRadius(8)
    }
}

struct ShopActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    let theme: ThemePreset
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let ink = Color(argb: theme.ink.argb)
        let fill = enabled && prominent ? Color(argb: theme.action.argb) : Color(argb: theme.surface.argb)
        return configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .multilineTextAlignment(.leading)
            .foregroundColor(enabled ? (prominent ? .white : ink) : Color(argb: theme.muted.argb))
            .background(fill)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ink.opacity(0.2)))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct ShopWindowHeading: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2).bold().accessibilityAddTraits(.isHeader)
            if let subtitle = subtitle {
                Text(subtitle).font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Color {
    init(argb: Int64) {
        self.init(red: Double((argb >> 16) & 255)/255, green: Double((argb >> 8) & 255)/255, blue: Double(argb & 255)/255)
    }
}


private struct BrandedShopHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image("SoiMark")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 44)
                .accessibilityLabel("Logo SÓI BARBERSHOP")
            ShopWindowHeading(title: title, subtitle: subtitle)
        }
    }
}
