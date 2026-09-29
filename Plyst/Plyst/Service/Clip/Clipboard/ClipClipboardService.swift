//
//  ClipClipboardService.swift
//  Plyst
//
//  Created by opfic on 9/29/26.
//

import Foundation

enum ClipClipboardSaveResult: Equatable, Sendable {
    case saved(Clip)
    /// 이미지 원본과 클립 기록은 저장됐지만 pending 표시 파일을 제거하지 못했습니다.
    /// recoverPendingCleanup()을 호출해야 정리를 다시 시도합니다.
    case savedWithPendingCleanup(Clip, fileID: UUID)
    case empty
    case unsupported
    case accessFailed
    case invalidImage
}

/// 사용자 저장 요청에 따라 클립보드를 읽고 클립을 추가합니다. 초기화 시에는 클립보드에 접근하지 않습니다.
/// storage와 images는 같은 저장소를 사용해야 합니다.
/// 이미지 루트별로 하나의 ClipImageService를 공유해야 합니다.
actor ClipClipboardService {
    private let storage: any ClipStorageService
    private let images: ClipImageService
    private let reader: any ClipboardReader
    private var isBusy = false
    private var waiters = [CheckedContinuation<Void, Never>]()

    init(
        storage: any ClipStorageService,
        images: ClipImageService,
        reader: any ClipboardReader = SystemClipboardReader()
    ) {
        self.storage = storage
        self.images = images
        self.reader = reader
    }

    /// 저장소 오류와 CancellationError는 그대로 전파합니다. 저장 확정 이후에는 취소를 다시 확인하지 않습니다.
    func saveCurrentClipboard() async throws -> ClipClipboardSaveResult {
        try await acquire()
        defer { release() }
        switch try await reader.read() {
        case .text(let text):
            let content = ClipContent.text(text)
            guard content.isValid else { return .empty }
            try Task.checkCancellation()
            let clip = Clip(content: content)
            try await storage.insert(clip)
            return .saved(clip)
        case .image(let data):
            try Task.checkCancellation()
            do {
                let result = try await images.saveImage(data)
                switch result.cleanup {
                case .completed:
                    return .saved(result.value)
                case .pending(let fileID):
                    return .savedWithPendingCleanup(result.value, fileID: fileID)
                }
            } catch let error as ClipImageFileError {
                switch error {
                case .invalidImage:
                    return .invalidImage
                case .unsupportedImage:
                    return .unsupported
                default:
                    throw error
                }
            }
        case .empty:
            return .empty
        case .unsupported:
            return .unsupported
        case .accessFailed:
            return .accessFailed
        }
    }

    /// actor의 재진입과 별개로 저장과 복사 작업 전체를 순서대로 처리합니다.
    private func acquire() async throws {
        try Task.checkCancellation()
        if isBusy {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            isBusy = true
        }
        do {
            try Task.checkCancellation()
        } catch {
            release()
            throw error
        }
    }

    private func release() {
        if waiters.isEmpty {
            isBusy = false
        } else { waiters.removeFirst().resume() }
    }
}
