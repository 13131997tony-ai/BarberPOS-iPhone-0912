import SwiftUI
import UIKit
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .list, .sound])
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct ChemicalAlarmMetadata: AlarmMetadata {}
#endif

struct TimerScreen: View {
    private struct Entry: Codable, Identifiable {
        let id: UUID
        let end: Date
        let alarm: Bool
    }
    let owner: String
    let theme: ThemePreset
    @Environment(\.presentationMode) private var presentation
    @State private var entries: [Entry] = []
    @State private var busy = false
    @State private var message: String?
    private var key: String { "barberpos.timers." + owner }
    private var supportsAlarm: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ShopWindowHeading(title: "Hẹn giờ hóa chất")
                Button("Đóng") { presentation.wrappedValue.dismiss() }.frame(minHeight: 44)
                DisclosureGroup("Cách nhận báo") {
                    Text(supportsAlarm
                         ? "Báo thức hệ thống khi được cấp quyền. Nếu không đặt được, ứng dụng thử dùng thông báo thường."
                         : "Thiết bị hoặc bản build này chỉ hỗ trợ thông báo thường. Âm thanh có thể bị tắt bởi chế độ Im lặng, Tập trung hoặc cài đặt thông báo.")
                }
                Text("Bắt đầu lượt mới").font(.headline).accessibilityAddTraits(.isHeader)
                ForEach([1, 5, 10, 15, 20, 30], id: \.self) { minutes in
                    Button("Bắt đầu · \(minutes) phút") { schedule(minutes) }
                        .frame(minHeight: 44).disabled(busy || entries.filter { $0.alarm || $0.end > Date() }.count >= 10)
                }
                if !entries.isEmpty { Text("Các lượt đã đặt").font(.headline).accessibilityAddTraits(.isHeader) }
                ForEach(entries) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.alarm ? "Báo thức hệ thống" : "Thông báo thường").bold()
                        Text(entry.end, style: .time)
                        if entry.end > Date() {
                            Text(entry.end, style: .timer).font(.title2).bold().monospacedDigit()
                        }
                        Button("Hủy hoặc dừng lượt") { cancel(entry) }.frame(minHeight: 44).disabled(busy)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(argb: theme.surface.argb)).cornerRadius(12)
                }
                if let message = message { Text(message) }
            }.padding()
        }
        .foregroundColor(Color(argb: theme.ink.argb))
        .accentColor(Color(argb: theme.focus.argb))
        .background(Color(argb: theme.background.argb).ignoresSafeArea())
        .onAppear {
            if let data = UserDefaults.standard.data(forKey: key),
               let saved = try? JSONDecoder().decode([Entry].self, from: data) {
                entries = saved.filter { $0.alarm || $0.end > Date() }
            }
            #if canImport(AlarmKit)
            if #available(iOS 26.0, *), let alarms = try? AlarmManager.shared.alarms {
                let active = Set(alarms.map(\.id))
                entries.removeAll { $0.alarm && !active.contains($0.id) }
            }
            #endif
            persist()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: key) }
    }

    private func schedule(_ minutes: Int) {
        busy = true
        message = nil
        let id = UUID()
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            Task { @MainActor in
                do {
                    let manager = AlarmManager.shared
                    guard try await manager.requestAuthorization() == .authorized else {
                        scheduleNotification(id, minutes)
                        return
                    }
                    let end = Date().addingTimeInterval(Double(minutes * 60))
                    let alert = AlarmPresentation.Alert(title: "Đã hết giờ hóa chất",
                        stopButton: AlarmButton(text: "Dừng", textColor: .white, systemImageName: "stop.fill"))
                    let attributes = AlarmAttributes<ChemicalAlarmMetadata>(
                        presentation: AlarmPresentation(alert: alert), tintColor: .red)
                    let configuration = AlarmManager.AlarmConfiguration<ChemicalAlarmMetadata>.alarm(
                        schedule: .fixed(end), attributes: attributes)
                    _ = try await manager.schedule(id: id, configuration: configuration)
                    entries.append(Entry(id: id, end: end, alarm: true))
                    persist()
                    message = "Đã đặt báo thức hệ thống."
                    busy = false
                } catch {
                    scheduleNotification(id, minutes)
                }
            }
            return
        }
        #endif
        scheduleNotification(id, minutes)
    }

    private func scheduleNotification(_ id: UUID, _ minutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                DispatchQueue.main.async {
                    busy = false
                    message = "Chưa có quyền thông báo. Hãy bật quyền trong Cài đặt iPhone hoặc dùng Đồng hồ hệ thống."
                }
                return
            }
            let seconds = Double(minutes * 60)
            let end = Date().addingTimeInterval(seconds)
            let content = UNMutableNotificationContent()
            content.title = "SÓI BarberPOS"
            content.body = "Đã hết giờ hóa chất."
            content.sound = .default
            center.add(UNNotificationRequest(identifier: id.uuidString, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))) { error in
                DispatchQueue.main.async {
                    busy = false
                    if error == nil {
                        entries.removeAll { !$0.alarm && $0.end <= Date() }
                        entries.append(Entry(id: id, end: end, alarm: false))
                        persist()
                        message = "Đã đặt thông báo thường, không có báo thức hệ thống cho lượt này. Âm thanh phụ thuộc cài đặt iPhone."
                    } else {
                        message = "Chưa đặt được thông báo."
                    }
                }
            }
        }
    }

    private func cancel(_ entry: Entry) {
        if entry.alarm {
            #if canImport(AlarmKit)
            if #available(iOS 26.0, *) {
                do {
                    let manager = AlarmManager.shared
                    if let alarm = try manager.alarms.first(where: { $0.id == entry.id }) {
                        if alarm.state == .alerting { try manager.stop(id: entry.id) }
                        else { try manager.cancel(id: entry.id) }
                    }
                } catch {
                    message = "Chưa dừng được báo thức. Kiểm tra trên màn hình khóa."
                    return
                }
            }
            #endif
        } else {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [entry.id.uuidString])
            center.removeDeliveredNotifications(withIdentifiers: [entry.id.uuidString])
        }
        entries.removeAll { $0.id == entry.id }
        persist()
    }
}
