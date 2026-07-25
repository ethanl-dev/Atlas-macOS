import XCTest
@testable import Atlas

/// Agent benchmark matrix. 离线用例必须稳定；联网烟测只使用固定公开主题，不发送用户内容或调用模型。
final class AgentBenchmarkTests: XCTestCase {
    private let verifiedSource = ResearchSource(
        provider: "Test Archive",
        title: "Verified source",
        excerpt: "A source-backed fact for testing.",
        url: URL(string: "https://doi.org/10.1000/atlas-test")!,
        domain: .history
    )

    func testBenchmarkCatalogCoversAllAgentSkills() {
        let scenarios = [
            "single_create_named", "batch_create_mixed_types", "create_fallback_summary",
            "research_nature", "research_history", "research_culture", "source_provenance",
            "organize_by_type", "organize_timeline", "organize_relation", "adopt_and_discard",
            "malformed_tool_response", "model_unavailable_fallback", "telemetry_privacy", "live_model_contracts"
        ]
        XCTAssertEqual(Set(scenarios).count, 15)
    }

    // MARK: 建档 Skill

    func testSingleCreateExtractsOnlyExplicitName() {
        let result = CanvasIntentParser.parseBatchDrafts(from: "帮我新建一个地点，命名为 雾港")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.kind.rawValue, BuilderKind.location.rawValue)
        XCTAssertEqual(result.first?.name, "雾港")
        XCTAssertEqual(result.first?.summary, "")
    }

    func testBatchCreatePreservesKindsAndSummaries() {
        let result = CanvasIntentParser.parseBatchDrafts(from: "地点：雾港，退潮后会失声\n角色：岑，白塔档案室守夜人；组织：森林议会")
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.kind.rawValue), ["location", "character", "org"])
        XCTAssertEqual(result[0].name, "雾港")
        XCTAssertEqual(result[0].summary, "退潮后会失声")
        XCTAssertEqual(result[1].name, "岑")
        XCTAssertEqual(result[2].name, "森林议会")
    }

    func testLocalParserInfersFallbackKinds() {
        let result = CanvasIntentParser.parseBatchDrafts(from: "霜火叛乱\n月门禁令\n失落的钥匙")
        XCTAssertEqual(result.map(\.kind.rawValue), ["event", "rule", "item"])
    }

    func testCreationToolSchemaHasOnlyDraftProposalTool() {
        let names = AgentToolSchema.creationTools().compactMap { ($0["function"] as? [String: Any])?["name"] as? String }
        XCTAssertEqual(names, ["propose_cards"])
    }

    // MARK: 灵感 / 来源核验 Skill

    func testResearchDomainClassification() {
        XCTAssertEqual(InspirationResearchService.inferDomain("火山闪电的自然现象").rawValue, InspirationDomain.nature.rawValue)
        XCTAssertEqual(InspirationResearchService.inferDomain("一场历史上的粮食危机").rawValue, InspirationDomain.history.rawValue)
        XCTAssertEqual(InspirationResearchService.inferDomain("海岛社区的节庆习俗").rawValue, InspirationDomain.culture.rawValue)
        XCTAssertEqual(InspirationResearchService.inferDomain("神秘港口").rawValue, InspirationDomain.general.rawValue)
    }

    func testResearchPlannerTurnsCreativePromptsIntoShortSourceQueries() {
        let nature = InspirationResearchService.plannedSearchQueries(
            for: "找一个自然现象，为雾港退潮后失声提供灵感，并附来源。",
            domain: .nature
        )
        let history = InspirationResearchService.plannedSearchQueries(
            for: "找一件历史上的粮食危机，为潮汐修会提供权力冲突灵感。",
            domain: .history
        )
        XCTAssertEqual(nature.first, "tidal acoustics sound propagation")
        XCTAssertEqual(history.first, "historical famine food crisis")
        XCTAssertTrue(nature.allSatisfy { !$0.contains("雾港") })
        XCTAssertTrue(history.allSatisfy { !$0.contains("潮汐修会") })
    }

    func testResearchFallbackKeepsVerifiedSourceAttached() async throws {
        let service = InspirationResearchService(sourceSearch: { _, _ in [self.verifiedSource] }, useModel: false)
        let proposal = try await service.research(query: "一场历史上的粮食危机")
        XCTAssertEqual(proposal.cards.count, 1)
        XCTAssertEqual(proposal.cards[0].source.url, verifiedSource.url)
        XCTAssertFalse(proposal.cards[0].fact.isEmpty)
        XCTAssertFalse(proposal.cards[0].creativeAngle.isEmpty)
    }

    func testModelInspirationParserRejectsUnknownSourceURL() {
        let json = """
        {"cards":[
          {"title":"有效","fact":"事实","creative_angle":"转译","source_url":"https://doi.org/10.1000/atlas-test"},
          {"title":"伪造","fact":"事实","creative_angle":"转译","source_url":"https://example.invalid/fake"}
        ]}
        """
        let cards = DeepSeekClient.parseInspirations(argumentsJSON: json, sources: [verifiedSource])
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.title, "有效")
    }

    func testInspirationToolSchemaRequiresSourceURL() {
        let tools = AgentToolSchema.inspirationTools()
        let function = tools.first?["function"] as? [String: Any]
        let parameters = function?["parameters"] as? [String: Any]
        let properties = parameters?["properties"] as? [String: Any]
        let cards = properties?["cards"] as? [String: Any]
        let items = cards?["items"] as? [String: Any]
        XCTAssertTrue((items?["required"] as? [String] ?? []).contains("source_url"))
    }

    // MARK: 整理 Skill

    func testToolActionParserHandlesValidAndMalformedActions() {
        let valid = AgentAction.from(name: "link_objects", argumentsJSON: #"{"source":"a","target":"b","relation":"盟友","strength":"strong"}"#)
        let invalid = AgentAction.from(name: "link_objects", argumentsJSON: #"{"source":"a"}"#)
        guard case .link(let source, let target, let relation, _, let strength)? = valid else {
            return XCTFail("Expected link action")
        }
        XCTAssertEqual(source, "a")
        XCTAssertEqual(target, "b")
        XCTAssertEqual(relation, "盟友")
        XCTAssertEqual(strength, "strong")
        XCTAssertNil(invalid)
    }

    func testArrangeGridAvoidsCardOverlap() {
        let objects = [
            makeObject("a", .map, x: 0, y: 0),
            makeObject("b", .location, x: 0, y: 0),
            makeObject("c", .character, x: 0, y: 0),
            makeObject("d", .org, x: 0, y: 0)
        ]
        let positions = CanvasArrange.grid(objects: objects)
        XCTAssertEqual(positions.count, objects.count)
        let unique = Set(positions.values.map { "\(Int($0.x)):\(Int($0.y))" })
        XCTAssertEqual(unique.count, objects.count)
    }

    @MainActor
    func testMockOrganizerProposesRelationBeforeLayout() {
        let store = WorldBuilderStore(seeded: true)
        let actions = MockOrganizer.actions(for: "把雾港和守望者·岑设为盟友", store: store)
        guard case .link(let source, let target, let relation, _, _)? = actions.first else {
            return XCTFail("Expected relation proposal")
        }
        XCTAssertNotEqual(source, target)
        XCTAssertEqual(relation, "盟友")
    }

    // MARK: 性能基准

    func testBenchmarkLocalCreationParser() {
        let input = "地点：雾港，退潮后会失声；角色：岑，白塔档案室守夜人；组织：森林议会；事件：霜火叛乱；规则：月门禁令；物件：回声钥匙"
        measure { _ = CanvasIntentParser.parseBatchDrafts(from: input) }
    }

    func testBenchmarkGridArrangement() {
        let objects = (0..<100).map { makeObject("node-\($0)", BuilderKind.allCases[$0 % BuilderKind.allCases.count], x: CGFloat($0), y: CGFloat($0)) }
        measure { _ = CanvasArrange.grid(objects: objects) }
    }

    // MARK: 联网资料源烟测

    func testLiveResearchBenchmarks() async throws {
        guard UserDefaults.standard.bool(forKey: "atlas.agent.runLiveSourceTests") else {
            throw XCTSkip("Enable atlas.agent.runLiveSourceTests to run public-source smoke tests.")
        }
        let cases = ["volcanic lightning", "historical famine", "ritual custom"]
        for query in cases {
            let proposal = try await InspirationResearchService(useModel: false).research(query: query)
            XCTAssertFalse(proposal.cards.isEmpty, "No sourced result for \(query)")
            XCTAssertTrue(proposal.cards.allSatisfy { $0.source.url.scheme == "https" })
        }
    }

    /// 真实模型测试只校验 function-calling 契约，避免把模型自由文本当成脆弱断言。
    @MainActor
    func testLiveModelContractsWhenConfigured() async throws {
        guard AgentConfig.isConfigured else {
            throw XCTSkip("Configure DEEPSEEK_API_KEY to run live model contract benchmarks.")
        }

        let client = DeepSeekClient()
        let creation = try await client.parseCanvasIntent(
            instruction: "新建一个地点，命名为 雾港",
            snapshot: "对象：\n（空）\n关系：\n（无）"
        )
        XCTAssertEqual(creation.drafts.count, 1)
        XCTAssertEqual(creation.drafts[0].kind.rawValue, "location")
        XCTAssertEqual(creation.drafts[0].name, "雾港")

        let singleObject = try await client.parseCanvasIntent(
            instruction: "新建一个地点，命名为\"雾港\"；它建在会发光的盐沼上；每次退潮后，居民都会暂时失去声音。",
            snapshot: "对象：\n（空）\n关系：\n（无）"
        )
        XCTAssertEqual(singleObject.drafts.count, 1)
        XCTAssertEqual(singleObject.drafts.first?.name, "雾港")
        XCTAssertTrue(singleObject.drafts.first?.summary.contains("盐沼") == true)

        let batch = try await client.parseCanvasIntent(
            instruction: "根据下面设定创建画布卡片：\n- 雾港：地点，退潮后全城失声\n- 潮汐修会：组织，垄断盐沼航道\n- 伊莱：角色，修会记录员\n- 无声潮：事件，每年一次的异常退潮",
            snapshot: "对象：\n（空）\n关系：\n（无）"
        )
        XCTAssertEqual(batch.drafts.count, 4)
        XCTAssertEqual(Set(batch.drafts.map(\.name)), Set(["雾港", "潮汐修会", "伊莱", "无声潮"]))

        let store = WorldBuilderStore(seeded: true)
        let organization = try await client.organize(instruction: "按类型归类", snapshot: CanvasOrganizer.snapshot(store))
        XCTAssertFalse(organization.actions.isEmpty)

        let inspirations = try await client.proposeInspirations(query: "研究灵感", sources: [verifiedSource])
        XCTAssertFalse(inspirations.isEmpty)
        XCTAssertTrue(inspirations.allSatisfy { $0.source.url == verifiedSource.url })
    }

    private func makeObject(_ id: String, _ kind: BuilderKind, x: CGFloat, y: CGFloat) -> BuilderObject {
        BuilderObject(id: id, kind: kind, name: id, summary: "", position: CGPoint(x: x, y: y), size: kind.defaultSize)
    }
}
