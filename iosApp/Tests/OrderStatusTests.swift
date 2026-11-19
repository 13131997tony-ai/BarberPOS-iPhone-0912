import Foundation
import XCTest
@testable import BarberPOSiOS

final class OrderStatusTests: XCTestCase {
    func testPaidOrderCancellationUsesServerDecision() throws {
        let approved = try decodeOrder(extra: ["paid_cancel_status": "APPROVED"])
        XCTAssertEqual(approved.statusLabel, "Đã hủy toàn bộ sau thu")
        XCTAssertEqual(approved.status, "PAID")

        let pending = try decodeOrder(extra: ["paid_cancel_status": "PENDING"])
        XCTAssertEqual(pending.statusLabel, "Chờ duyệt hủy toàn bộ")
    }

    func testLegacyPaidOrderAndPartialRefundKeepPaidLabel() throws {
        let paidLabel = "Đã hoàn thành · Đã thanh toán"
        XCTAssertEqual(try decodeOrder().statusLabel, paidLabel)
        let partial = try decodeOrder(extra: [
            "paid_cancel_status": NSNull(),
            "refunds": [["status": "APPROVED", "cash": 50000]],
        ])
        XCTAssertEqual(partial.statusLabel, paidLabel)
    }

    func testAwaitingPaymentKeepsExistingLabel() throws {
        XCTAssertEqual(try decodeOrder(status: "CONFIRMED").statusLabel, "Chờ thanh toán")
    }

    func testActiveDraftAndCancelledLabelsRemainUnchanged() throws {
        XCTAssertEqual(try decodeOrder(status: "CONFIRMED", extra: ["services_completed": false]).statusLabel,
                       "Đang thực hiện")
        XCTAssertEqual(try decodeOrder(status: "DRAFT").statusLabel, "Nháp · Chưa xác nhận")
        XCTAssertEqual(try decodeOrder(status: "CANCELLED").statusLabel, "Đã hủy")
    }

    private func decodeOrder(status: String = "PAID", extra: [String: Any] = [:]) throws -> ShopOrder {
        var fields: [String: Any] = [
            "id": 27,
            "status": status,
            "created_at": "2026-11-18T10:00:00+07:00",
            "services_completed": true,
            "lines": [],
        ]
        fields.merge(extra) { _, new in new }
        let data = try JSONSerialization.data(withJSONObject: fields)
        return try JSONDecoder().decode(ShopOrder.self, from: data)
    }
}
