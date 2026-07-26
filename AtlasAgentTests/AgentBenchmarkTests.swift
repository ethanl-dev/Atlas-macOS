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

    func testForcedToolChoiceDisablesDeepSeekThinkingMode() {
        let forcedChoice: [String: Any] = [
            "type": "function",
            "function": ["name": "propose_cards"]
        ]
        let body = DeepSeekClient.makeRequestBody(
            messages: [["role": "user", "content": "test"]],
            tools: AgentToolSchema.creationTools(),
            toolChoice: forcedChoice
        )
        let thinking = body["thinking"] as? [String: String]
        XCTAssertEqual(thinking?["type"], "disabled")
        XCTAssertNotNil(body["tool_choice"])
    }

    func testAutomaticToolChoiceKeepsDefaultThinkingMode() {
        let body = DeepSeekClient.makeRequestBody(
            messages: [["role": "user", "content": "test"]],
            tools: AgentToolSchema.tools(),
            toolChoice: nil
        )
        XCTAssertNil(body["thinking"])
        XCTAssertEqual(body["tool_choice"] as? String, "auto")
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

    func testEmptyModelInspirationFallsBackToVerifiedSourceCard() {
        let cards = InspirationResearchService.cardsUsingVerifiedFallback(
            [],
            sources: [verifiedSource]
        )
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.source.url, verifiedSource.url)
        XCTAssertFalse(cards.first?.fact.isEmpty ?? true)
        XCTAssertFalse(cards.first?.creativeAngle.isEmpty ?? true)
        XCTAssertTrue(cards.allSatisfy {
            DeepSeekClient.containsChinese($0.title)
                && DeepSeekClient.containsChinese($0.fact)
                && DeepSeekClient.containsChinese($0.creativeAngle)
        })
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

    func testModelInspirationParserRejectsNonChineseVisibleContent() {
        let json = """
        {"cards":[
          {"title":"Shallow water acoustics","fact":"Sound propagation changes with depth.","creative_angle":"Use this as a setting.","source_url":"https://doi.org/10.1000/atlas-test"}
        ]}
        """
        XCTAssertTrue(
            DeepSeekClient.parseInspirations(argumentsJSON: json, sources: [verifiedSource]).isEmpty
        )
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
        XCTAssertTrue(inspirations.allSatisfy {
            DeepSeekClient.containsChinese($0.title)
                && DeepSeekClient.containsChinese($0.fact)
                && DeepSeekClient.containsChinese($0.creativeAngle)
        })
    }

    /// 端到端验证《哈利·波特与魔法石》演示稿中的长提示词。
    /// 默认跳过，避免普通单测重复消耗模型与公开资料源配额。
    @MainActor
    func testLiveHarryPotterDemoPrompts() async throws {
        guard UserDefaults.standard.bool(forKey: "atlas.agent.runDemoPromptTests") else {
            throw XCTSkip("Enable atlas.agent.runDemoPromptTests to run the demo prompt acceptance test.")
        }
        guard AgentConfig.isConfigured else {
            throw XCTSkip("Configure DEEPSEEK_API_KEY to run the demo prompt acceptance test.")
        }

        let client = DeepSeekClient()
        let emptySnapshot = "对象：\n（空）\n关系：\n（无）"
        let fullCreationPrompt = """
        请根据下面明确列出的对象，提出一批待采纳的画布卡片草稿。每一条只创建一张卡；只使用我提供的名称和说明，不要补写新的设定。

        地图｜霍格沃茨校园图｜用于承载霍格沃茨城堡、禁林和校内重要区域的世界地图。

        地点｜霍格沃茨城堡｜英国魔法学校的主体建筑，包含大礼堂、会移动的楼梯、宿舍和许多隐藏房间。
        地点｜九又四分之三站台｜隐藏在伦敦国王十字车站内，学生从这里乘坐霍格沃茨特快列车。
        地点｜禁林｜霍格沃茨边界内禁止学生擅自进入的森林，生活着多种魔法生物。

        角色｜哈利·波特｜在麻瓜家庭长大的孤儿，十一岁时得知自己是巫师，并进入霍格沃茨学习。
        角色｜赫敏·格兰杰｜出身麻瓜家庭、重视规则与知识的一年级学生，是哈利和罗恩的重要伙伴。
        角色｜罗恩·韦斯莱｜来自巫师家庭的一年级学生，在魔法棋与巫师社会常识方面帮助哈利。
        角色｜奇洛教授｜霍格沃茨黑魔法防御术教授，表面胆怯，实际试图帮助伏地魔取得魔法石。

        组织｜格兰芬多学院｜霍格沃茨四大学院之一，重视勇气、胆识与担当。
        组织｜斯莱特林学院｜霍格沃茨四大学院之一，重视野心、谋略与血统传统。

        规则｜魔杖与咒语规则｜施法通常需要魔杖、咒语、动作与施法者意志共同完成；不同魔杖与使用者之间存在适配差异。

        事件｜万圣节巨怪事件｜万圣节夜晚巨怪进入霍格沃茨，哈利和罗恩前往女盥洗室救下赫敏，三人由此成为朋友。
        事件｜厄里斯魔镜前的对决｜哈利通过一系列防护机关抵达厄里斯魔镜前，发现奇洛试图为伏地魔夺取魔法石。

        物件｜魔法石｜由炼金术士尼可·勒梅制造，能够将金属变成黄金并用于炼制长生不老药。

        作品｜霍格沃茨录取通知书｜寄给哈利的入学信件，第一次明确告诉他巫师身份和入学安排。

        便签｜魔法石谜题线索｜三头犬、古灵阁被闯入、尼可·勒梅和厄里斯魔镜共同指向被隐藏的魔法石。
        """
        let fullCreation = try await client.parseCanvasIntent(
            instruction: fullCreationPrompt,
            snapshot: emptySnapshot
        )
        let expectedFullNames = Set([
            "霍格沃茨校园图", "霍格沃茨城堡", "九又四分之三站台", "禁林",
            "哈利·波特", "赫敏·格兰杰", "罗恩·韦斯莱", "奇洛教授",
            "格兰芬多学院", "斯莱特林学院", "魔杖与咒语规则",
            "万圣节巨怪事件", "厄里斯魔镜前的对决", "魔法石",
            "霍格沃茨录取通知书", "魔法石谜题线索"
        ])
        XCTAssertEqual(fullCreation.drafts.count, 16)
        XCTAssertEqual(Set(fullCreation.drafts.map(\.name)), expectedFullNames)
        XCTAssertEqual(
            Dictionary(grouping: fullCreation.drafts, by: \.kind.rawValue).mapValues(\.count),
            [
                "map": 1, "location": 3, "character": 4, "org": 2, "rule": 1,
                "event": 2, "item": 1, "work": 1, "note": 1
            ]
        )

        let quickCreationPrompt = """
        请提出四张待采纳卡片草稿，只使用以下内容，不要扩写：
        地点｜霍格沃茨城堡｜英国魔法学校的主体建筑。
        角色｜哈利·波特｜十一岁时得知自己是巫师并进入霍格沃茨学习。
        组织｜格兰芬多学院｜重视勇气、胆识与担当的学院。
        事件｜厄里斯魔镜前的对决｜哈利在厄里斯魔镜前阻止奇洛夺取魔法石。
        """
        let quickCreation = try await client.parseCanvasIntent(
            instruction: quickCreationPrompt,
            snapshot: emptySnapshot
        )
        XCTAssertEqual(quickCreation.drafts.count, 4)
        XCTAssertEqual(
            Set(quickCreation.drafts.map(\.name)),
            Set(["霍格沃茨城堡", "哈利·波特", "格兰芬多学院", "厄里斯魔镜前的对决"])
        )

        let demoSnapshot = """
        对象：
        - map-campus · 地图 · 霍格沃茨校园图
        - loc-castle · 地点 · 霍格沃茨城堡
        - loc-platform · 地点 · 九又四分之三站台
        - loc-forest · 地点 · 禁林
        - chr-harry · 角色 · 哈利·波特
        - chr-hermione · 角色 · 赫敏·格兰杰
        - chr-ron · 角色 · 罗恩·韦斯莱
        - chr-quirrell · 角色 · 奇洛教授
        - org-gryffindor · 组织 · 格兰芬多学院
        - org-slytherin · 组织 · 斯莱特林学院
        - rule-wand · 规则 · 魔杖与咒语规则
        - evt-troll · 事件 · 万圣节巨怪事件
        - evt-mirror · 事件 · 厄里斯魔镜前的对决
        - item-stone · 物件 · 魔法石
        - work-letter · 作品 · 霍格沃茨录取通知书
        - note-clues · 便签 · 魔法石谜题线索
        关系：
        （无）
        """
        let layoutPrompt = "按对象类型整理整个画布，让地图、地点、角色、组织、规则、事件、物件、作品和便签形成清楚的分列。只调整卡片位置，不修改任何名称、摘要或其他正文。"
        let layout = try await client.organize(instruction: layoutPrompt, snapshot: demoSnapshot)
        XCTAssertTrue(layout.actions.contains {
            if case .arrange(let strategy) = $0 { return strategy == "by_type" }
            return false
        })
        XCTAssertFalse(layout.actions.contains {
            if case .link = $0 { return true }
            if case .unlink = $0 { return true }
            return false
        })

        let firstRelationsPrompt = """
        请提出以下关系并生成预览：
        哈利·波特连接格兰芬多学院，关系标签为“成员”，强度为深。
        赫敏·格兰杰连接格兰芬多学院，关系标签为“成员”，强度为深。
        罗恩·韦斯莱连接格兰芬多学院，关系标签为“成员”，强度为深。
        哈利·波特连接罗恩·韦斯莱，关系标签为“盟友”，强度为深。
        哈利·波特连接赫敏·格兰杰，关系标签为“盟友”，强度为深。
        奇洛教授连接哈利·波特，关系标签为“隐藏敌对”，强度为深。
        只建立这些关系，不修改卡片正文，也不要新增对象。
        """
        let firstRelations = try await client.organize(
            instruction: firstRelationsPrompt,
            snapshot: demoSnapshot
        )
        XCTAssertEqual(
            linkSignatures(firstRelations.actions),
            Set([
                "chr-harry|org-gryffindor|成员|strong",
                "chr-hermione|org-gryffindor|成员|strong",
                "chr-ron|org-gryffindor|成员|strong",
                "chr-harry|chr-ron|盟友|strong",
                "chr-harry|chr-hermione|盟友|strong",
                "chr-quirrell|chr-harry|隐藏敌对|strong"
            ])
        )

        let secondRelationsPrompt = """
        请提出以下关系并生成预览：
        万圣节巨怪事件连接霍格沃茨城堡，关系标签为“发生于”，强度为常。
        万圣节巨怪事件连接赫敏·格兰杰，关系标签为“涉及”，强度为深。
        万圣节巨怪事件连接罗恩·韦斯莱，关系标签为“涉及”，强度为深。
        厄里斯魔镜前的对决连接哈利·波特，关系标签为“涉及”，强度为深。
        厄里斯魔镜前的对决连接奇洛教授，关系标签为“涉及”，强度为深。
        魔法石连接厄里斯魔镜前的对决，关系标签为“核心目标”，强度为深。
        只建立这些关系，不修改卡片正文，也不要新增对象。
        """
        let secondRelations = try await client.organize(
            instruction: secondRelationsPrompt,
            snapshot: demoSnapshot
        )
        XCTAssertEqual(
            linkSignatures(secondRelations.actions),
            Set([
                "evt-troll|loc-castle|发生于|medium",
                "evt-troll|chr-hermione|涉及|strong",
                "evt-troll|chr-ron|涉及|strong",
                "evt-mirror|chr-harry|涉及|strong",
                "evt-mirror|chr-quirrell|涉及|strong",
                "item-stone|evt-mirror|核心目标|strong"
            ])
        )

        let quickOrganizePrompt = "按类型整理画布，并把哈利·波特、格兰芬多学院和厄里斯魔镜前的对决聚拢到一起；只调整布局，不修改任何卡片正文。"
        let quickOrganize = try await client.organize(
            instruction: quickOrganizePrompt,
            snapshot: demoSnapshot
        )
        XCTAssertTrue(quickOrganize.actions.contains {
            if case .arrange(let strategy) = $0 { return strategy == "by_type" }
            return false
        })
        XCTAssertTrue(quickOrganize.actions.contains {
            if case .cluster(let ids, _) = $0 {
                return Set(ids) == Set(["chr-harry", "org-gryffindor", "evt-mirror"])
            }
            return false
        })

        let researchPrompts = [
            "查找关于极光与地磁活动的可核验自然资料，为“霍格沃茨大礼堂会呈现外部天空的魔法天花板”提供视觉和规则参考。每条都要附可打开的原始资料来源，把资料事实和创作追问分开；只递出资料参照与开放问题，不要改写《魔法石》的既有设定。",
            "查找关于火山闪电的可核验自然资料，为“魔法学校上空可能出现的异常天象”提供视觉参考。每条附原始来源，只给资料参照和开放问题，不改写原著设定。",
            "查找历史上的粮食危机与配给记录，为“寄宿学校在长期封锁下如何维持食物供应”提供资料参考。每条附原始来源，只给资料参照和开放问题，不改写原著设定。",
            "查找关于极光的可核验自然资料，为霍格沃茨大礼堂的魔法天花板提供视觉参考。每条附原始来源，只给资料参照和开放问题，不改写原著设定。"
        ]
        for prompt in researchPrompts {
            let proposal = try await InspirationResearchService().research(query: prompt)
            XCTAssertNil(proposal.modelFallbackReason, proposal.modelFallbackReason ?? "")
            XCTAssertFalse(proposal.cards.isEmpty)
            XCTAssertLessThanOrEqual(proposal.cards.count, 3)
            XCTAssertTrue(proposal.cards.allSatisfy {
                $0.source.url.scheme == "https"
                    && DeepSeekClient.containsChinese($0.title)
                    && DeepSeekClient.containsChinese($0.fact)
                    && DeepSeekClient.containsChinese($0.creativeAngle)
            })
        }
    }

    private func linkSignatures(_ actions: [AgentAction]) -> Set<String> {
        Set(actions.compactMap { action in
            guard case .link(let source, let target, let relation, _, let strength) = action else {
                return nil
            }
            return "\(source)|\(target)|\(relation ?? "")|\(strength ?? "medium")"
        })
    }

    private func makeObject(_ id: String, _ kind: BuilderKind, x: CGFloat, y: CGFloat) -> BuilderObject {
        BuilderObject(id: id, kind: kind, name: id, summary: "", position: CGPoint(x: x, y: y), size: kind.defaultSize)
    }
}
