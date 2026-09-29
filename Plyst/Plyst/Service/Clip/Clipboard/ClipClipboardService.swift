//
//  ClipClipboardService.swift
//  Plyst
//
//  Created by opfic on 9/29/26.
//

enum ClipClipboardSaveResult: Equatable, Sendable {
    case saved(Clip)
    case empty
    case unsupported
    case accessFailed
}

/// 사용자 저장 요청에 따라 클립보드를 읽고 텍스트 클립을 추가합니다. 초기화 시에는 클립보드에 접근하지 않습니다.
struct ClipClipboardService: Sendable {
    private let storage: any ClipStorageService
    private let reader: any ClipboardReader

    init(
        storage: any ClipStorageService,
        reader: any ClipboardReader = SystemClipboardReader()
    ) {
        self.storage = storage
        self.reader = reader
    }

    /// 저장소 오류와 CancellationError는 그대로 전파합니다. 저장 확정 이후에는 취소를 다시 확인하지 않습니다.
    func saveCurrentClipboard() async throws -> ClipClipboardSaveResult {
        try Task.checkCancellation()
        switch try await reader.read() {
        case .text(let text):
            let content = ClipContent.text(text)
            guard content.isValid else { return .empty }
            try Task.checkCancellation()
            let clip = Clip(content: content)
            try await storage.insert(clip)
            return .saved(clip)
        case .empty:
            return .empty
        case .unsupported:
            return .unsupported
        case .accessFailed:
            return .accessFailed
        }
    }
}
