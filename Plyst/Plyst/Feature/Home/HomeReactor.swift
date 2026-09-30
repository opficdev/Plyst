//
//  HomeReactor.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import Foundation
import ReactorKit
import RxSwift

struct HomeThumbnailKey: Hashable, Sendable {
    let clipID: Clip.ID
    let fileID: UUID
    let maximumPixelDimension: Int
}

final class HomeReactor: Reactorable {
    enum Action: Sendable {
        case viewDidLoad
        case timeChanged(Date)
        case saveCurrentClipboard
        case dismissFeedback(UUID)
        case thumbnailRequested(HomeThumbnailKey)
        case thumbnailCancelled(HomeThumbnailKey)
        case selectFilter(HomeFilter)
    }

    enum Mutation: Sendable {
        case clipsLoaded([Clip], Date)
        case loadFailed
        case timeChanged(Date)
        case savingStarted
        case savingStopped
        case saveResult(ClipClipboardSaveResult, UUID)
        case saveFailed(UUID)
        case feedbackDismissed(UUID)
        case thumbnailStarted(HomeThumbnailKey)
        case thumbnailLoaded(HomeThumbnailKey, Data)
        case thumbnailFailed(HomeThumbnailKey)
        case thumbnailCancelled(HomeThumbnailKey)
        case filterSelected(HomeFilter)
    }

    enum LoadPhase: Sendable {
        case initial
        case loaded
        case failed
    }

    struct Feedback: Equatable, Sendable {
        let id: UUID
        let message: String
        let isSuccess: Bool
    }

    struct State: Sendable {
        var clips = [Clip]()
        var now = Date()
        var loadPhase = LoadPhase.initial
        var isSaving = false
        var feedback: Feedback?
        var thumbnails = [HomeThumbnailKey: Data]()
        var thumbnailOrder = [HomeThumbnailKey]()
        var loadingThumbnails = Set<HomeThumbnailKey>()
        var failedThumbnails = Set<HomeThumbnailKey>()
        var filter = HomeFilter.all

        var content: HomeContent {
            HomeContent.make(from: clips, filter: filter, now: now, calendar: .current)
        }
    }

    let initialState = State()

    private let storage: any ClipStorageService
    private let clipboard: ClipClipboardService
    private let images: ClipImageService

    init(
        storage: any ClipStorageService,
        clipboard: ClipClipboardService,
        images: ClipImageService
    ) {
        self.storage = storage
        self.clipboard = clipboard
        self.images = images
    }

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .viewDidLoad:
            let storage = storage
            return ReactorEffect.stream { continuation in
                let changes = await storage.changes()
                await Self.load(storage: storage, into: continuation)
                for await _ in changes {
                    await Self.load(storage: storage, into: continuation)
                }
            }

        case .timeChanged(let now):
            return .just(.timeChanged(now))

        case .saveCurrentClipboard:
            guard !currentState.isSaving else { return .empty() }
            let clipboard = clipboard
            let images = images
            let effect = ReactorEffect.task {
                let result = try await clipboard.saveCurrentClipboard()
                if case .savedWithPendingCleanup = result {
                    // 저장 확정은 유지하고 파일 정리만 별도로 다시 시도합니다.
                    Task { [images] in _ = try? await images.recoverPendingCleanup() }
                }
                return result
            }
                .map { Mutation.saveResult($0, UUID()) }
                .catch { _ in .just(.saveFailed(UUID())) }
            return .concat([
                .just(.savingStarted),
                effect,
                .just(.savingStopped)
            ])

        case .dismissFeedback(let id):
            return .just(.feedbackDismissed(id))

        case .thumbnailRequested(let key):
            guard 0 < key.maximumPixelDimension,
                  currentState.thumbnails[key] == nil,
                  !currentState.loadingThumbnails.contains(key),
                  !currentState.failedThumbnails.contains(key),
                  let clip = currentState.clips.first(where: { $0.id == key.clipID }),
                  case .image(let image) = clip.content,
                  image.fileID == key.fileID else { return .empty() }

            let images = images
            let cancelled = self.action.filter { action in
                guard case .thumbnailCancelled(let other) = action else { return false }
                return other == key
            }
            let effect = ReactorEffect.task {
                try await images.loadThumbnail(image, maximumPixelDimension: key.maximumPixelDimension)
            }
            .map { Mutation.thumbnailLoaded(key, $0) }
            .catch { _ in .just(.thumbnailFailed(key)) }
            .take(until: cancelled)
            return .concat([
                .just(.thumbnailStarted(key)),
                effect
            ])

        case .thumbnailCancelled(let key):
            return .just(.thumbnailCancelled(key))

        case .selectFilter(let filter):
            guard currentState.filter != filter else { return .empty() }
            return .just(.filterSelected(filter))
        }
    }

    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        switch mutation {
        case .clipsLoaded(let clips, let now):
            state.clips = clips
            state.now = now
            state.loadPhase = .loaded
            let valid = Set(clips.compactMap { clip -> UUID? in
                guard case .image(let image) = clip.content else { return nil }
                return image.fileID
            })
            state.thumbnails = state.thumbnails.filter { valid.contains($0.key.fileID) }
            state.thumbnailOrder.removeAll { !valid.contains($0.fileID) }
            state.loadingThumbnails = state.loadingThumbnails.filter { valid.contains($0.fileID) }
            state.failedThumbnails = state.failedThumbnails.filter { valid.contains($0.fileID) }

        case .loadFailed:
            state.loadPhase = .failed

        case .timeChanged(let now):
            state.now = now

        case .savingStarted:
            state.isSaving = true

        case .savingStopped:
            state.isSaving = false

        case .saveResult(let result, let id):
            let message: String
            let success: Bool
            switch result {
            case .saved, .savedWithPendingCleanup:
                message = "Plyst에 저장했습니다"
                success = true
            case .empty:
                message = "현재 클립보드에 저장할 내용이 없습니다"
                success = false
            case .unsupported:
                message = "지원하지 않는 클립보드 형식입니다"
                success = false
            case .accessFailed:
                message = "현재 클립보드를 읽지 못했습니다"
                success = false
            case .invalidImage:
                message = "이미지가 올바르지 않아 저장하지 못했습니다"
                success = false
            }
            state.feedback = Feedback(id: id, message: message, isSuccess: success)

        case .saveFailed(let id):
            state.feedback = Feedback(id: id, message: "클립을 저장하지 못했습니다", isSuccess: false)

        case .feedbackDismissed(let id):
            if state.feedback?.id == id { state.feedback = nil }

        case .thumbnailStarted(let key):
            state.loadingThumbnails.insert(key)

        case .thumbnailLoaded(let key, let data):
            guard state.loadingThumbnails.remove(key) != nil,
                  state.clips.contains(where: { clip in
                      guard clip.id == key.clipID, case .image(let image) = clip.content else { return false }
                      return image.fileID == key.fileID
                  }) else { return state }
            state.thumbnails[key] = data
            state.thumbnailOrder.removeAll { $0 == key }
            state.thumbnailOrder.append(key)
            while 48 < state.thumbnailOrder.count {
                let oldest = state.thumbnailOrder.removeFirst()
                state.thumbnails.removeValue(forKey: oldest)
            }

        case .thumbnailFailed(let key):
            state.loadingThumbnails.remove(key)
            state.failedThumbnails.insert(key)

        case .thumbnailCancelled(let key):
            state.loadingThumbnails.remove(key)

        case .filterSelected(let filter):
            state.filter = filter
        }
        return state
    }

    private static func load(
        storage: any ClipStorageService,
        into continuation: AsyncThrowingStream<Mutation, Error>.Continuation
    ) async {
        do {
            let clips = try await storage.fetchAll(order: .createdAt)
            continuation.yield(.clipsLoaded(clips, Date()))
        } catch is CancellationError {
            return
        } catch {
            continuation.yield(.loadFailed)
        }
    }
}
