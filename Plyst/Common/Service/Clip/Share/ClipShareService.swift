//
//  ClipShareService.swift
//  Plyst
//
//  Created by opfic on 10/1/26.
//

import Foundation
import UniformTypeIdentifiers

/// 공유 시트로 받은 텍스트나 URL을 텍스트 클립으로 저장합니다. 이미지와 여러 항목은 다루지 않습니다.
///
/// 저장을 시도할 때마다 첨부를 다시 읽으므로 읽기 실패 후에도 같은 항목으로 다시 시도할 수 있습니다.
/// 읽기나 검증에 실패하면 저장소에 쓰지 않습니다. 저장소 오류와 CancellationError는 그대로 전파합니다.
struct ClipShareService: Sendable {
    private let storage: any ClipStorageService

    init(storage: any ClipStorageService) {
        self.storage = storage
    }

    func saveText(_ item: ClipShareItem) async throws -> ClipShareSaveResult {
        let text: String?
        do {
            text = try await Self.loadText(from: item)
        } catch {
            try Task.checkCancellation()
            return .loadFailed
        }
        guard let text, ClipContent.text(text).isValid else { return .empty }
        // 저장이 시작된 뒤에는 취소를 다시 확인하지 않습니다.
        try Task.checkCancellation()
        let clip = Clip(content: .text(text), name: item.title)
        try await storage.insert(clip)
        return .saved(clip)
    }

    /// 지원하는 첫 첨부만 읽습니다. 같은 첨부에서는 텍스트를 우선하고 공백뿐이면 URL로 대체합니다.
    /// 지원하는 첨부가 없으면 nil입니다. URL은 정규화하지 않고 원본 문자열을 그대로 사용합니다.
    @MainActor
    private static func loadText(from item: ClipShareItem) async throws -> String? {
        let textType = UTType.plainText.identifier
        let urlType = UTType.url.identifier
        guard let provider = item.providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(textType) || $0.hasItemConformingToTypeIdentifier(urlType)
        }) else { return nil }
        let hasURL = provider.hasItemConformingToTypeIdentifier(urlType)
        if provider.hasItemConformingToTypeIdentifier(textType) {
            let text = try await load(from: provider, typeIdentifier: textType)
            if ClipContent.text(text).isValid || !hasURL { return text }
        }
        return try await load(from: provider, typeIdentifier: urlType)
    }

    /// 완료 핸들러에서만 continuation을 재개하므로 정확히 한 번 재개합니다.
    /// loadObject는 공유한 앱이 NSString을 객체로 등록한 경우 읽지 못하므로 등록된 항목을 그대로 돌려주는 loadItem을 사용합니다.
    @MainActor
    private static func load(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let text = string(from: item, typeIdentifier: typeIdentifier) {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                }
            }
        }
    }

    /// 항목의 실제 형식에 맞춰 문자열로 바꿉니다. 지원하지 않는 형식은 nil입니다.
    private nonisolated static func string(
        from item: (any NSSecureCoding)?,
        typeIdentifier: String
    ) -> String? {
        switch item {
        case let text as String:
            text
        case let url as URL:
            url.absoluteString
        case let data as Data:
            urlString(from: data, typeIdentifier: typeIdentifier) ?? String(data: data, encoding: .utf8)
        case let attributed as NSAttributedString:
            attributed.string
        default:
            nil
        }
    }

    /// NSURL이 제공한 URL 데이터는 UTF-8 문자열이 아닐 수 있습니다. 따라서 NSURL의 해석을 먼저 사용합니다.
    private nonisolated static func urlString(
        from data: Data,
        typeIdentifier: String
    ) -> String? {
        guard UTType(typeIdentifier)?.conforms(to: .url) == true else { return nil }
        return (try? NSURL.object(withItemProviderData: data, typeIdentifier: typeIdentifier))?.absoluteString
    }
}
