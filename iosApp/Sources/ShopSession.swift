import Foundation
import Combine

struct ShopOverview: Decodable {
    struct Orders: Decodable {
        let doing: Int
        let waiting: Int
    }
    let orders: Orders?
    let pending: Int
    let reviewable: Int
}

struct ShopProfile: Decodable {
    let username: String; let name: String; let role: String; let csrf: String
    let themePreset: String?
    let overview: ShopOverview?
    enum CodingKeys: String, CodingKey {
        case username, name, role, csrf
        case themePreset = "theme_preset"
        case overview = "shop_overview"
    }
}
struct OrderLine: Decodable { let serviceName: String; let performerName: String
    enum CodingKeys: String, CodingKey { case serviceName = "service_name", performerName = "performer_name" }
}
struct ShopOrder: Decodable, Identifiable {
    let id: Int64; let status: String; let createdAt: String; let customerLabel: String?
    let servicesCompleted: Bool; let lines: [OrderLine]
    let paidCancelStatus: String?

    var statusLabel: String {
        // Whole-order cancellation is separate from the original paid receipt and partial refunds.
        if status == "PAID" {
            switch paidCancelStatus ?? "" {
            case "APPROVED": return "Đã hủy toàn bộ sau thu"
            case "PENDING": return "Chờ duyệt hủy toàn bộ"
            default: break
            }
        }
        switch status {
        case "PAID": return "Đã hoàn thành · Đã thanh toán"
        case "CANCELLED": return "Đã hủy"
        case "DRAFT": return "Nháp · Chưa xác nhận"
        default: return servicesCompleted ? "Chờ thanh toán" : "Đang thực hiện"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, status, lines
        case createdAt = "created_at"
        case customerLabel = "customer_label"
        case servicesCompleted = "services_completed"
        case paidCancelStatus = "paid_cancel_status"
    }
}
struct ShopAppearance: Decodable {
    let themePreset: String?
    let revision: String
    enum CodingKeys: String, CodingKey { case themePreset = "theme_preset", revision }
}
struct ShopService: Decodable, Identifiable {
    let id: String
    let name: String
    let price: Int64
    let categoryID: String?
    let categoryName: String?
    enum CodingKeys: String, CodingKey {
        case id, name, price
        case categoryID = "category_id"
        case categoryName = "category_name"
    }
}
struct OrderEnvelope: Decodable {
    let drafts: [ShopOrder]
    let services: [ShopService]
}

/** Ephemeral cookies: no password or session token in UserDefaults, files, or diagnostics. */
final class ShopSession: ObservableObject {
    @Published var profile: ShopProfile?
    @Published var shopPreset = "GRAPHITE_RED"
    @Published var orders: [ShopOrder] = []
    @Published var services: [ShopService] = []
    @Published var overviewLoading = false
    @Published var overviewFailed = false
    @Published var busy = false
    @Published var error: String?
    private let base = URL(string: "https://app.barberpos-tiem.win")!
    private var transport: URLSession = ShopSession.makeTransport()
    private static func makeTransport() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }
    func login(username: String, password: String) {
        guard !busy else { return };busy = true;error = nil
        var request = URLRequest(url: base.appendingPathComponent("login"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(base.absoluteString, forHTTPHeaderField: "Origin")
        var parts = URLComponents()
        parts.queryItems = [URLQueryItem(name:"username",value:username),URLQueryItem(name:"password",value:password),URLQueryItem(name:"device_label",value:"BarberPOS iOS")]
        request.httpBody = parts.percentEncodedQuery?.replacingOccurrences(of:"+",with:"%2B").data(using:.utf8)
        transport.dataTask(with:request) { [weak self] _, response, failure in
            guard let self = self else { return }
            guard failure == nil, let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
                DispatchQueue.main.async { self.busy=false;self.error="Đăng nhập chưa thành công. Kiểm tra tài khoản và kết nối." };return
            }
            self.readProfile()
        }.resume()
    }
    private func readProfile() {
        read("api/android-session", as: ShopProfile.self) { result in
            self.busy=false
            switch result { case .success(let profile):self.profile=profile;self.shopPreset=profile.themePreset ?? "GRAPHITE_RED";self.loadOrders()
            case .failure:self.error="Phiên không hợp lệ hoặc máy chủ chưa kết nối được." }
        }
    }
    func refreshOverview() {
        guard let current = profile, !overviewLoading, current.role != "BARBER" else { return }
        overviewLoading = true
        overviewFailed = false
        read("api/android-session", as: ShopProfile.self) { result in
            guard self.profile?.csrf == current.csrf else { return }
            self.overviewLoading = false
            switch result {
            case .success(let profile): self.profile = profile
            case .failure: self.overviewFailed = true
            }
        }
    }

    func loadAppearance() {
        read("api/android-session", as: ShopProfile.self) { result in
            if case .success(let settings) = result, self.profile?.csrf == settings.csrf {
                self.shopPreset = settings.themePreset ?? "GRAPHITE_RED"
            }
        }
    }

    func saveAppearance(_ preset: String) {
        guard let profile = profile, profile.role == "OWNER", !busy else { return }
        busy = true
        error = nil
        read("api/shop-settings", as: ShopAppearance.self) { result in
            guard self.profile?.csrf == profile.csrf else { self.busy = false; return }
            guard case .success(let settings) = result else {
                self.busy = false
                self.error = "Chưa tải được cấu hình của tiệm."
                return
            }
            var request = URLRequest(url: self.base.appendingPathComponent("api/shop-settings"))
            request.httpMethod = "POST"
            request.setValue(self.base.absoluteString, forHTTPHeaderField: "Origin")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var form = URLComponents()
            form.queryItems = [
                URLQueryItem(name: "csrf", value: profile.csrf),
                URLQueryItem(name: "group", value: "appearance"),
                URLQueryItem(name: "revision", value: settings.revision),
                URLQueryItem(name: "theme_preset", value: preset),
            ]
            request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
            self.transport.dataTask(with: request) { _, response, failure in
                DispatchQueue.main.async {
                    self.busy = false
                    guard self.profile?.csrf == profile.csrf else { return }
                    guard failure == nil, let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        self.error = "Chưa xác nhận được bộ mặc định. Mở lại Giao diện để kiểm tra."
                        return
                    }
                    self.loadAppearance()
                }
            }.resume()
        }
    }

    func loadOrders() {
        read("api/shared-drafts", as:OrderEnvelope.self) { result in
            switch result { case .success(let data):self.orders=data.drafts;self.services=data.services
            case .failure:self.error="Không tải được danh sách. Kiểm tra phiên và kết nối." }
        }
    }
    private func read<T:Decodable>(_ path:String, as type:T.Type, completion:@escaping(Result<T,Error>)->Void) {
        var request=URLRequest(url:base.appendingPathComponent(path));request.setValue("application/json",forHTTPHeaderField:"Accept")
        transport.dataTask(with:request){data,response,error in
            let result:Result<T,Error>
            if let error=error { result = .failure(error) }
            else if let http=response as? HTTPURLResponse, http.statusCode==200, let data=data {
                result=Result { try JSONDecoder().decode(type,from:data) }
            } else { result = .failure(URLError(.userAuthenticationRequired)) }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }
    func logout() {
        guard let profile=profile else{return}
        var request=URLRequest(url:base.appendingPathComponent("logout"));request.httpMethod="POST"
        request.setValue(base.absoluteString,forHTTPHeaderField:"Origin")
        request.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
        var parts=URLComponents();parts.queryItems=[URLQueryItem(name:"csrf",value:profile.csrf)]
        request.httpBody=parts.percentEncodedQuery?.data(using:.utf8)
        transport.dataTask(with:request){[weak self] _,_,_ in DispatchQueue.main.async {
            guard let self=self else{return};self.transport.invalidateAndCancel();self.transport=ShopSession.makeTransport();self.profile=nil;self.orders=[];self.services=[];self.shopPreset="GRAPHITE_RED";self.overviewLoading=false;self.overviewFailed=false
        }}.resume()
    }
}
