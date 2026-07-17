import Foundation

/// Client for the shared, no-key AI proxy (`apps-ai-proxy`). No secret is
/// embedded — abuse is bounded server-side by the proxy's own per-IP rate
/// limiter. Only the `/text` route is used (Kitchenline has no vision
/// feature).
///
/// Both public calls throw only for genuine transport/HTTP failure — a
/// malformed model response is never surfaced as an error; it silently
/// resolves to the hand-written fallback plan/sequence via
/// `PracticePlanParser`/`GhostRallyParser` so a flaky response never blanks a
/// screen or crashes the app.
final class AIProxyClient {

    enum APIError: LocalizedError {
        case badStatus(Int)
        case emptyResponse
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .badStatus, .emptyResponse:
                return "The practice coach is briefly unavailable. Showing a default plan instead."
            case .network:
                return "Couldn't reach the practice coach. Check your connection — showing a default plan instead."
            }
        }
    }

    static let baseURL = URL(string: "https://apps-ai-proxy.s0533495227.workers.dev")!

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: Public

    /// Builds a personalized weekly practice plan from the player's self-rated
    /// weak shots and how many minutes they have today. Only drills from the
    /// bundled library are usable — the system prompt lists every drill name
    /// verbatim and `PracticePlanParser` fuzzy-matches against the same list.
    func fetchPracticePlan(weakShots: [WeakShotTag], minutesAvailable: Int) async throws -> PracticePlan {
        let content = try await sendText(
            systemPrompt: Self.planSystemPrompt,
            userText: Self.planUserText(weakShots: weakShots, minutes: minutesAvailable)
        )
        return PracticePlanParser.parse(content) ?? FallbackPlanner.generate(weakShots: weakShots, minutesAvailable: minutesAvailable)
    }

    /// Asks for a short sequence of opponent court-position waypoints tailored
    /// to one specific drill, for ghost-rally mode.
    func fetchGhostRally(for drill: Drill) async throws -> [GhostWaypoint] {
        let content = try await sendText(
            systemPrompt: Self.ghostSystemPrompt,
            userText: Self.ghostUserText(drill: drill)
        )
        return GhostRallyParser.parse(content) ?? FallbackPlanner.ghostWaypoints(for: drill)
    }

    // MARK: Prompts

    private static let allDrillNames = DrillLibrary.all.map(\.name).joined(separator: ", ")

    private static let planSystemPrompt = """
    You are a pickleball drill coach building a short personalized weekly practice \
    plan. You may reference ONLY these exact drill names, spelled exactly as given, \
    no others: \(allDrillNames).

    Given the player's self-rated weak shots and how many minutes they have to \
    practice today, choose 3 to 4 practice days. Each day should focus on one or two \
    of the weak shots and list 2 to 3 drills (by exact name from the list above) with \
    a sensible rep count for the minutes available.

    Respond with ONLY a JSON object, no markdown fences, no commentary, exactly in \
    this shape:
    {"days":[{"day":"Day 1","focus":"short focus label","minutes":number,"drills":[{"drillName":"exact name from the list","reps":number}]}]}
    """

    private static func planUserText(weakShots: [WeakShotTag], minutes: Int) -> String {
        let shots = weakShots.isEmpty ? "no specific weak shots selected — pick a balanced mix" : weakShots.map(\.rawValue).joined(separator: ", ")
        return "Self-rated weak shots: \(shots). Practice minutes available today: \(minutes)."
    }

    private static let ghostSystemPrompt = """
    You are simulating a simplified pickleball opponent as a short sequence of \
    court positions for a 2D top-down animated diagram — NOT a real photo or video \
    opponent, just a labeled dot that moves.

    Court coordinates: x runs 0 (left sideline) to 20 (right sideline) in feet; y \
    runs 0 to 44 (baseline to baseline) in feet. The net is at y=22. The kitchen \
    (non-volley zone) spans y=15 to y=29.

    Return ONLY a JSON array of 3 to 6 waypoints describing where a realistic \
    opponent would move over roughly 1 to 2 seconds while this exact point is being \
    drilled, with time increasing and starting at 0. No markdown fences, no \
    commentary, exactly in this shape:
    [{"time":number,"courtX":number,"courtY":number}]
    """

    private static func ghostUserText(drill: Drill) -> String {
        "Drill being practiced: \(drill.name) — \(drill.summary)"
    }

    // MARK: Transport

    private func sendText(systemPrompt: String, userText: String) async throws -> String {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("text"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

        let body = ChatRequest(messages: [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: userText),
        ])
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw APIError.network(error)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.badStatus(status)
        }
        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw APIError.emptyResponse
        }
        return content
    }
}

// MARK: - Wire types (matches apps-ai-proxy's OpenAI-compatible chat-completions shape)

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let messages: [Message]
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}
