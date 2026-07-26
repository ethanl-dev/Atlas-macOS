import Foundation

enum InspirationDomain: String {
    case nature
    case history
    case culture
    case general

    var title: String {
        switch self {
        case .nature: return "自然"
        case .history: return "历史"
        case .culture: return "文化"
        case .general: return "资料"
        }
    }
}

struct ResearchSource: Identifiable {
    let id = UUID()
    let provider: String
    let title: String
    let excerpt: String
    let url: URL
    let domain: InspirationDomain
}

struct InspirationCard: Identifiable {
    let id = UUID()
    let title: String
    let fact: String
    let creativeAngle: String
    let source: ResearchSource
}

struct InspirationResearchProposal {
    let domain: InspirationDomain
    let searchQueries: [String]
    let cards: [InspirationCard]
    let modelFallbackReason: String?
    let duration: TimeInterval
}

enum InspirationResearchError: LocalizedError {
    case noSources

    var errorDescription: String? { "没有找到可核验的公开资料。换一个更具体的现象、事件、地区或物种试试。" }
}

/// 只从能回到原始馆藏/机构页面的开放资料源取材；模型只负责转译，不能把它当作事实来源。
struct InspirationResearchService {
    typealias SourceSearch = (_ query: String, _ domain: InspirationDomain) async throws -> [ResearchSource]

    private let sourceSearchOverride: SourceSearch?
    private let useModel: Bool

    init(sourceSearch: SourceSearch? = nil, useModel: Bool = true) {
        self.sourceSearchOverride = sourceSearch
        self.useModel = useModel
    }

    func research(query: String) async throws -> InspirationResearchProposal {
        let startedAt = Date()
        let domain = Self.inferDomain(query)
        let searchQueries = Self.plannedSearchQueries(for: query, domain: domain)
        let sources: [ResearchSource]
        if let sourceSearchOverride {
            sources = try await sourceSearchOverride(query, domain)
        } else {
            sources = try await sourceSearch(queries: searchQueries, domain: domain)
        }
        guard !sources.isEmpty else { throw InspirationResearchError.noSources }

        let cards: [InspirationCard]
        let modelFallbackReason: String?
        if useModel && AgentConfig.isConfigured {
            do {
                let proposed = try await DeepSeekClient().proposeInspirations(query: query, sources: sources)
                cards = Self.cardsUsingVerifiedFallback(proposed, sources: sources)
                if proposed.isEmpty {
                    modelFallbackReason = "模型返回的资料卡未通过来源与格式校验，已显示来源保底摘要。"
                    AgentTelemetry.track(
                        "agent_inspiration_model_fallback",
                        properties: ["domain": domain.rawValue, "reason": "empty_cards"]
                    )
                } else {
                    modelFallbackReason = nil
                }
            } catch {
                modelFallbackReason = "模型转译失败：\(error.localizedDescription) 已显示来源保底摘要。"
                AgentTelemetry.track(
                    "agent_inspiration_model_fallback",
                    properties: ["domain": domain.rawValue, "reason": Self.fallbackReasonCode(error)]
                )
                cards = Self.localCards(from: sources)
            }
        } else {
            cards = Self.localCards(from: sources)
            modelFallbackReason = useModel ? "AI 未连接，已显示来源保底摘要。" : nil
        }
        return InspirationResearchProposal(
            domain: domain,
            searchQueries: searchQueries,
            cards: cards,
            modelFallbackReason: modelFallbackReason,
            duration: Date().timeIntervalSince(startedAt)
        )
    }

    /// A model may return no usable cards when its source URL differs even
    /// slightly from the verified URL. Never expose an empty "verified"
    /// proposal: fall back to source-backed editorial cards instead.
    static func cardsUsingVerifiedFallback(
        _ proposed: [InspirationCard],
        sources: [ResearchSource]
    ) -> [InspirationCard] {
        proposed.isEmpty ? localCards(from: sources) : proposed
    }

    static func inferDomain(_ text: String) -> InspirationDomain {
        if contains(text, ["物种", "动物", "植物", "火山", "地震", "洪水", "飓风", "野火", "极光", "潮汐", "海洋", "气候", "自然", "生态"]) {
            return .nature
        }
        if contains(text, ["历史", "朝代", "战争", "革命", "古代", "遗址", "档案", "手稿", "年代", "饥荒", "粮食危机", "粮荒"]) { return .history }
        if contains(text, ["习俗", "节庆", "仪式", "民俗", "文化", "地区", "族群", "社区"]) { return .culture }
        return .general
    }

    /// 把创作描述缩成资料源真正能理解的检索词。这里只做检索翻译，不产出任何事实。
    static func plannedSearchQueries(for text: String, domain: InspirationDomain) -> [String] {
        let mappings: [(String, [String])]
        switch domain {
        case .nature:
            mappings = [
                ("潮汐", ["tidal acoustics sound propagation", "tidal bore natural phenomenon"]),
                ("退潮", ["tidal acoustics sound propagation", "tidal bore natural phenomenon"]),
                ("火山闪电", ["volcanic lightning"]),
                ("火山", ["volcanic natural phenomena"]),
                ("极光", ["aurora natural phenomenon"])
            ]
        case .history:
            mappings = [
                ("粮食危机", ["historical famine food crisis"]),
                ("粮荒", ["historical famine food crisis"]),
                ("饥荒", ["historical famine"])
            ]
        case .culture:
            mappings = [
                ("习俗", ["ethnographic study customary practice"]),
                ("仪式", ["ethnographic study ritual practice"])
            ]
        case .general:
            mappings = []
        }
        let specific = mappings.first(where: { text.contains($0.0) })?.1 ?? []
        let fallback: String
        switch domain {
        case .nature: fallback = "natural phenomenon scientific study"
        case .history: fallback = "historical event archival study"
        case .culture: fallback = "ethnographic primary source collection"
        case .general: fallback = text
        }
        return Array(NSOrderedSet(array: specific + [fallback])).compactMap { $0 as? String }.prefix(2).map { $0 }
    }

    private func sourceSearch(queries: [String], domain: InspirationDomain) async throws -> [ResearchSource] {
        for query in queries {
            if domain == .nature,
               let events = try? await eonetSources(query: query), !events.isEmpty {
                return events
            }
            if let academicSources = try? await openAlexSources(query: query, domain: domain), !academicSources.isEmpty {
                return academicSources
            }
            if let crossrefSources = try? await crossrefSources(query: query, domain: domain), !crossrefSources.isEmpty {
                return crossrefSources
            }
            if let archiveSources = try? await libraryOfCongressSources(query: query, domain: domain), !archiveSources.isEmpty {
                return archiveSources
            }
        }
        throw InspirationResearchError.noSources
    }

    /// OpenAlex 是检索层；展示链接优先回到 DOI 的原始论文，而不是把索引条目当证据本身。
    private func openAlexSources(query: String, domain: InspirationDomain) async throws -> [ResearchSource] {
        var components = URLComponents(string: "https://api.openalex.org/works")!
        components.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "per-page", value: "5")
        ]
        let (data, response) = try await fetch(components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let results = payload["results"] as? [[String: Any]] ?? []
        return results.compactMap { record in
            guard let title = record["title"] as? String else { return nil }
            let rawURL = (record["doi"] as? String) ?? (record["id"] as? String)
            guard let rawURL, let url = URL(string: rawURL) else { return nil }
            let venue = ((record["primary_location"] as? [String: Any])?["source"] as? [String: Any])?["display_name"] as? String
            let provider = venue.map { "OpenAlex · \($0)" } ?? "OpenAlex 学术索引"
            return ResearchSource(
                provider: provider,
                title: title,
                excerpt: abstractExcerpt(from: record) ?? "可通过 DOI 回到原始论文或出版记录。",
                url: url,
                domain: domain
            )
        }
    }

    private func libraryOfCongressSources(query: String, domain: InspirationDomain) async throws -> [ResearchSource] {
        var components = URLComponents(string: "https://www.loc.gov/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fo", value: "json"),
            URLQueryItem(name: "c", value: "5")
        ]
        let (data, response) = try await fetch(components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let results = payload["results"] as? [[String: Any]] ?? []
        return results.compactMap { record in
            guard let title = record["title"] as? String,
                  let id = record["id"] as? String,
                  let url = URL(string: id) else { return nil }
            let description = (record["description"] as? [String])?.first
                ?? (record["description"] as? String)
                ?? "美国国会图书馆数字馆藏条目。"
            return ResearchSource(provider: "美国国会图书馆", title: title, excerpt: description, url: url, domain: domain)
        }
    }

    /// Crossref 提供 DOI 元数据，链接直接回到出版物记录；它是 OpenAlex 失效时的独立学术检索兜底。
    private func crossrefSources(query: String, domain: InspirationDomain) async throws -> [ResearchSource] {
        var components = URLComponents(string: "https://api.crossref.org/works")!
        components.queryItems = [
            URLQueryItem(name: "query.bibliographic", value: query),
            URLQueryItem(name: "rows", value: "5")
        ]
        let (data, response) = try await fetch(components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let message = payload["message"] as? [String: Any] ?? [:]
        let items = message["items"] as? [[String: Any]] ?? []
        return items.compactMap { item in
            guard let doi = item["DOI"] as? String,
                  let url = URL(string: "https://doi.org/\(doi)"),
                  let title = (item["title"] as? [String])?.first,
                  !title.isEmpty else { return nil }
            let venue = (item["container-title"] as? [String])?.first ?? "学术出版记录"
            let abstract = (item["abstract"] as? String).map(Self.cleanHTML)
            return ResearchSource(
                provider: "Crossref · \(venue)",
                title: title,
                excerpt: abstract?.isEmpty == false ? abstract! : "可通过 DOI 回到出版物或原始文献记录。",
                url: url,
                domain: domain
            )
        }
    }

    private func eonetSources(query: String) async throws -> [ResearchSource] {
        var components = URLComponents(string: "https://eonet.gsfc.nasa.gov/api/v3/events")!
        components.queryItems = [URLQueryItem(name: "status", value: "all"), URLQueryItem(name: "limit", value: "50")]
        let (data, response) = try await fetch(components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let events = payload["events"] as? [[String: Any]] ?? []
        let terms = query.lowercased().split(separator: " ").map(String.init) + Self.natureTerms(in: query)
        return events.compactMap { event in
            guard let title = event["title"] as? String,
                  let id = event["id"] as? String else { return nil }
            let categories = (event["categories"] as? [[String: Any]] ?? []).compactMap { $0["title"] as? String }.joined(separator: " · ")
            let haystack = "\(title) \(categories)".lowercased()
            guard terms.contains(where: { haystack.contains($0.lowercased()) }) else { return nil }
            let url = URL(string: "https://eonet.gsfc.nasa.gov/api/v3/events/\(id)")!
            return ResearchSource(provider: "NASA EONET", title: title, excerpt: categories.isEmpty ? "NASA 自然事件记录。" : "事件类别：\(categories)", url: url, domain: .nature)
        }.prefix(5).map { $0 }
    }

    private static func localCards(from sources: [ResearchSource]) -> [InspirationCard] {
        sources.prefix(3).enumerated().map { index, source in
            InspirationCard(
                title: "\(source.domain.title)资料参照 \(index + 1)",
                fact: "已找到一条与当前问题相关、可以回到原始页面核验的\(source.domain.title)资料。当前仅把它作为检索入口，不代替原文结论。",
                creativeAngle: "可以追问：原文中哪一种可验证的变化机制，值得带回当前画布继续讨论？",
                source: source
            )
        }
    }

    private func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("AtlasResearch/1.0", forHTTPHeaderField: "User-Agent")
        return try await URLSession.shared.data(for: request)
    }

    private func abstractExcerpt(from record: [String: Any]) -> String? {
        guard let inverted = record["abstract_inverted_index"] as? [String: [Int]] else { return nil }
        let words = inverted.flatMap { word, positions in positions.map { ($0, word) } }
            .sorted { $0.0 < $1.0 }
            .prefix(70)
            .map(\.1)
        guard !words.isEmpty else { return nil }
        return words.joined(separator: " ")
    }

    private static func cleanHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    private static func contains(_ text: String, _ words: [String]) -> Bool { words.contains { text.contains($0) } }

    private static func fallbackReasonCode(_ error: Error) -> String {
        switch error {
        case DeepSeekError.notConfigured: return "not_configured"
        case DeepSeekError.timedOut: return "timed_out"
        case DeepSeekError.http: return "http_error"
        case DeepSeekError.badResponse: return "bad_response"
        default: return "unknown"
        }
    }

    private static func natureTerms(in text: String) -> [String] {
        let mapping = [
            "火山": "volcano", "地震": "earthquake", "洪水": "flood", "飓风": "storm",
            "野火": "wildfire", "风暴": "storm", "冰": "ice", "极光": "aurora"
        ]
        return mapping.compactMap { text.contains($0.key) ? $0.value : nil }
    }
}
