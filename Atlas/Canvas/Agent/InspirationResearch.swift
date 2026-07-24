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
    let cards: [InspirationCard]
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
        let sources: [ResearchSource]
        if let sourceSearchOverride {
            sources = try await sourceSearchOverride(query, domain)
        } else {
            sources = try await sourceSearch(query: query, domain: domain)
        }
        guard !sources.isEmpty else { throw InspirationResearchError.noSources }

        let cards: [InspirationCard]
        if useModel && AgentConfig.isConfigured {
            do {
                cards = try await DeepSeekClient().proposeInspirations(query: query, sources: sources)
            } catch {
                AgentTelemetry.track("agent_inspiration_model_fallback", properties: ["domain": domain.rawValue])
                cards = Self.localCards(from: sources)
            }
        } else {
            cards = Self.localCards(from: sources)
        }
        return InspirationResearchProposal(domain: domain, cards: cards, duration: Date().timeIntervalSince(startedAt))
    }

    static func inferDomain(_ text: String) -> InspirationDomain {
        if contains(text, ["物种", "动物", "植物", "火山", "地震", "洪水", "飓风", "野火", "极光", "潮汐", "海洋", "气候", "自然", "生态"]) {
            return .nature
        }
        if contains(text, ["历史", "朝代", "战争", "革命", "古代", "遗址", "档案", "手稿", "年代"]) { return .history }
        if contains(text, ["习俗", "节庆", "仪式", "民俗", "文化", "地区", "族群", "社区"]) { return .culture }
        return .general
    }

    private func sourceSearch(query: String, domain: InspirationDomain) async throws -> [ResearchSource] {
        if domain == .nature,
           let events = try? await eonetSources(query: query), !events.isEmpty {
            return events
        }
        if let academicSources = try? await openAlexSources(query: query, domain: domain), !academicSources.isEmpty {
            return academicSources
        }
        if let archiveSources = try? await libraryOfCongressSources(query: query, domain: domain), !archiveSources.isEmpty {
            return archiveSources
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
        sources.prefix(3).map { source in
            InspirationCard(
                title: source.title,
                fact: source.excerpt,
                creativeAngle: "可借鉴它的节律、边界或组织方式；在世界中另行命名与重构，不把资料本身当作设定。",
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

    private static func contains(_ text: String, _ words: [String]) -> Bool { words.contains { text.contains($0) } }

    private static func natureTerms(in text: String) -> [String] {
        let mapping = [
            "火山": "volcano", "地震": "earthquake", "洪水": "flood", "飓风": "storm",
            "野火": "wildfire", "风暴": "storm", "冰": "ice", "极光": "aurora"
        ]
        return mapping.compactMap { text.contains($0.key) ? $0.value : nil }
    }
}
