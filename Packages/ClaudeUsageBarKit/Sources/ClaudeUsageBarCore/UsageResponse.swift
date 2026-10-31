import Foundation

/// One window object; each field is read on its own so one bad field spoils only itself.
private struct WindowPayload: Decodable {
    private enum CodingKeys: String, CodingKey {
        case resetsAt = "resets_at"
        case utilization
    }

    let utilization: Double?
    let resetsAt: String?

    /// `nil` without a utilization: a window with no number has nothing to show.
    var window: UsageWindow? {
        guard let utilization else {
            return nil
        }
        return UsageWindow(
            utilization: utilization,
            resetsAt: resetsAt.flatMap(UsageTimestamp.date(from:)),
        )
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        utilization = try? container.decodeIfPresent(Double.self, forKey: .utilization)
        resetsAt = try? container.decodeIfPresent(String.self, forKey: .resetsAt)
    }
}

/// The two keys of the endpoint's JSON object this app reads.
private struct Payload: Decodable {
    private enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    let fiveHour: WindowPayload?
    let sevenDay: WindowPayload?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try? container.decodeIfPresent(WindowPayload.self, forKey: .fiveHour)
        sevenDay = try? container.decodeIfPresent(WindowPayload.self, forKey: .sevenDay)
    }
}

/// An HTTP answer from the usage endpoint, as the fetching adapter hands it over.
///
/// The adapter only translates `URLSession`'s answer into this value; what a status or a
/// body *means* is decided in ``snapshot()``, where a test can reach every branch.
public struct UsageResponse: Equatable, Sendable {
    /// The statuses that mean something other than "unexpected".
    private enum Status {
        static let success = 200 ..< 300
        static let unauthorized = 401
        static let forbidden = 403
    }

    /// The HTTP status code.
    public let statusCode: Int
    /// The response body, unparsed.
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    /// The usage this answer reports.
    ///
    /// Decoding is lenient on purpose: the endpoint is undocumented and returns many
    /// keys this app ignores, so a missing, `null`, or wrongly typed window or field
    /// makes only that part absent. Only a body that is not a JSON object at all fails.
    ///
    /// - Throws: ``UsageError/tokenExpired`` for 401 and 403,
    ///   ``UsageError/unexpectedResponse(statusCode:)`` for any other non-2xx status or
    ///   an unreadable body.
    public func snapshot() throws(UsageError) -> UsageSnapshot {
        if statusCode == Status.unauthorized || statusCode == Status.forbidden {
            throw .tokenExpired
        }
        guard Status.success.contains(statusCode),
              let payload = try? JSONDecoder().decode(Payload.self, from: body)
        else {
            throw .unexpectedResponse(statusCode: statusCode)
        }
        return UsageSnapshot(
            fiveHour: payload.fiveHour?.window,
            sevenDay: payload.sevenDay?.window,
        )
    }
}
