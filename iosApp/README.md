# SÓI BarberPOS 0.9.11 cho iPhone

Gói mã nguồn iOS riêng, build số 37, dùng bundle ID `vn.barberpos.ios`. Ứng dụng kết nối máy chủ BarberPOS qua HTTPS.

- **Hôm nay** mở menu dịch vụ, hẹn giờ, danh sách đơn được phép xem và khu vực vận hành.
- **Bộ giao diện** có sáu bộ màu từ `shared-spec/theme-presets.json`. Người dùng có thể chọn màu riêng trên thiết bị. Lưu mặc định chung của tiệm cần tài khoản Chủ tiệm và máy chủ hỗ trợ bảng màu mới.
- **Nghiệp vụ** mở trong WebView. Tạo/sửa đơn, thanh toán, chấm công và phê duyệt dùng quy trình và quyền trên máy chủ. WebView dùng phiên đăng nhập riêng và có nút Đóng, Quay lại và Về trang chính.
- **Hẹn giờ** dùng AlarmKit khi SDK và thiết bị hỗ trợ và người dùng cấp quyền. Nếu cần, ứng dụng thử dùng thông báo thường. Kiểm tra báo âm thanh trên iPhone thật, bao gồm khi khóa màn hình và bật Tập trung.

## Chạy thử trên Mac

1. Giải nén nguyên thư mục `BarberPOS_iPhone`. Giữ `shared-spec` cạnh `iosApp` để Xcode đóng gói sáu bộ màu.
2. Cài Xcode, tải nền tảng iOS trong Xcode và cài [XcodeGen](https://github.com/yonaskolb/XcodeGen). Dùng Xcode có SDK iOS 26 để build phần AlarmKit.
3. Trong Terminal, chạy lệnh sau từ thư mục `BarberPOS_iPhone`.

   ```sh
   bash iosApp/KIEM_TRA_TREN_MAC.command
   ```

4. Mở `iosApp/BarberPOSiOS.xcodeproj`, chọn scheme **BarberPOSiOS** và trình mô phỏng rồi chạy **Product → Test**.
5. Để chạy trên iPhone thật, kết nối iPhone với Mac, mở **Signing & Capabilities**, chọn Team có quyền ký bundle ID, chọn iPhone và bấm **Run**. Xem [hướng dẫn chạy trên thiết bị của Apple](https://developer.apple.com/documentation/xcode/building-and-running-an-app).

Tùy chọn `IOS_SIMULATOR_DESTINATION` cho phép script chạy test trên máy mô phỏng có sẵn. Có thể xem các đích bằng `xcrun simctl list devices available`.

## Gói IPA

`codemagic.yaml` tạo IPA arm64 chưa ký từ mã nguồn này. Tên IPA lấy từ phiên bản của ứng dụng. Với bản 0.9.11, đầu ra là `BarberPOS_0.9.11_iPhone_Unsigned.ipa`.

Trên Codemagic, đặt `codemagic.yaml`, `iosApp` và `shared-spec` ở thư mục gốc của kho mã. Chọn nhánh chứa các tệp mới và chạy workflow **BarberPOS iPhone USB - unsigned IPA**. Khi thành công, tải tệp trong **Artifacts**.

Nếu bước **Package the unsigned IPA** vẫn lỗi, tìm dòng `IPA packaging:` hoặc `IPA packaging failed` trong log. Dòng đó xác định phần cần kiểm tra, chẳng hạn đường dẫn ứng dụng, khóa phiên bản, kiến trúc arm64 hoặc tệp màu. Đối chiếu dòng đầu của bước đóng gói để xác nhận nhánh đang chạy dùng đường dẫn `build/ios-device/products/BarberPOSiOS.app`.

Bản chưa ký cần được ký bằng cấu hình phân phối phù hợp trước khi cài. Để phân phối qua TestFlight, dùng Xcode Archive với Team của dự án và làm theo quy trình App Store Connect.

## Kiểm tra trước khi phát hành

Kiểm tra đăng nhập, mở đúng đơn từ Hôm nay, hành động dành cho chủ tiệm và thợ, sáu bộ màu, chữ lớn, quay lại trong WebView, nhận và hủy báo giờ. Gói này đặt iOS 15 làm phiên bản tối thiểu để khớp với Xcode 26.2. Tương thích trên thiết bị thật, build và chữ ký cần được xác nhận trên Mac.
