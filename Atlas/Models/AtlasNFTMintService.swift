import Foundation

enum AtlasNFTMintState {
    case idle
    case preparing
    case submitting
    case confirmed(AtlasNFTMintReceipt)
    case failed(String)
}

struct AtlasNFTMintReceipt {
    let tokenId: Int
    let transactionHash: String
    let mode: String
    let contentHash: String
    let timestamp: Date
}

actor AtlasNFTMintService {
    static let shared = AtlasNFTMintService()

    private struct MintRequest: Encodable {
        let address: String
        let projectId: Int
        let workId: String
        let contentHash: String
    }

    private struct MintResponse: Decodable {
        let success: Bool
        let mode: String?
        let tokenId: Int?
        let tx: String?
        let error: String?
    }

    func mint(
        workID: String,
        projectID: Int?,
        creatorAddress: String,
        contentHash: String
    ) async throws -> AtlasNFTMintReceipt {
        guard let endpoint = ProcessInfo.processInfo.environment["ATLAS_NFT_API"],
              let baseURL = URL(string: endpoint),
              !endpoint.isEmpty else {
            return try await mockMint(contentHash: contentHash)
        }

        let url = baseURL.appendingPathComponent("mint")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 18
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            MintRequest(
                address: creatorAddress,
                projectId: projectID ?? 1,
                workId: workID,
                contentHash: contentHash
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MintError.invalidResponse
        }

        let payload = try JSONDecoder().decode(MintResponse.self, from: data)
        guard (200..<300).contains(http.statusCode), payload.success else {
            throw MintError.backend(payload.error ?? "Mint 请求失败")
        }

        return AtlasNFTMintReceipt(
            tokenId: payload.tokenId ?? 0,
            transactionHash: payload.tx ?? "交易已提交",
            mode: payload.mode ?? "injective",
            contentHash: contentHash,
            timestamp: Date()
        )
    }

    private func mockMint(contentHash: String) async throws -> AtlasNFTMintReceipt {
        try await Task.sleep(for: .milliseconds(900))
        let tokenId = Int.random(in: 100...999)
        return AtlasNFTMintReceipt(
            tokenId: tokenId,
            transactionHash: "0xMOCK\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))",
            mode: "mock",
            contentHash: contentHash,
            timestamp: Date()
        )
    }

    private enum MintError: LocalizedError {
        case invalidResponse
        case backend(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "上链服务没有返回有效响应"
            case .backend(let message):
                return message
            }
        }
    }
}
