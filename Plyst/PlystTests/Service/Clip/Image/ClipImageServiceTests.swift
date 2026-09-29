//
//  ClipImageServiceTests.swift
//  PlystTests
//
//  Created by opfic on 9/29/26.
//

import Foundation
import XCTest
@testable import Plyst

final class ClipImageServiceTests: XCTestCase {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Plyst-image-service-\(UUID())", isDirectory: true)
    private var root: URL { directory.appendingPathComponent("images", isDirectory: true) }

    override func tearDownWithError() throws {
        try ClipImageFileSystemTestFixture.restorePermissions(at: directory)
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
        try super.tearDownWithError()
    }

    func testSavedClipAndOriginalAreRestoredByNewInstances() async throws {
        let data = try ClipImageTestFixture.data()
        let repository = try makeRepository()
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: repository, files: files)
        let result = try await service.saveImage(data, name: "이름", memo: "메모", isPinned: true)
        XCTAssertEqual(result.cleanup, .completed)
        let reopened = ClipImageService(repository: try makeRepository(), files: try ClipImageFileStore(rootURL: root))
        let restored = try await reopened.loadImage(id: result.value.id)
        let clip = try await repository.fetch(id: result.value.id)
        XCTAssertEqual(restored, data)
        XCTAssertEqual(clip, result.value)
        XCTAssertEqual(clip?.name, "이름")
        XCTAssertTrue(clip?.isPinned == true)
        XCTAssertEqual(try files.pendingFileIDs(), [])
    }

    func testDuplicateInsertCleansOnlyNewOriginalAndDoesNotPublish() async throws {
        let data = try ClipImageTestFixture.data()
        let repository = try makeRepository()
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: repository, files: files)
        let result = try await service.saveImage(data)
        let stream = await repository.changes()
        do {
            _ = try await service.saveImage(data, id: result.value.id)
            XCTFail("중복 식별자 저장 성공")
        } catch { XCTAssertEqual(error as? ClipRepositoryError, .duplicateID(result.value.id)) }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).count, 1)
        let original = try await service.loadImage(id: result.value.id)
        XCTAssertEqual(original, data)
        _ = try await service.delete(id: result.value.id)
        await assertEvents(stream, expected: [.deleted(result.value.id)])
    }

    func testRejectedInsertPreservesRepositoryErrorAndCleansFile() async throws {
        let spy = ClipImageRepositorySpy(repository: try makeRepository())
        await spy.reject(.insert)
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: spy, files: files)
        let stream = await spy.changes()
        do {
            _ = try await service.saveImage(ClipImageTestFixture.data())
            XCTFail("실패하도록 설정한 삽입 성공")
        } catch { XCTAssertEqual(error as? ClipRepositoryError, .writeFailed) }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
        await spy.allow(.insert)
        let sentinel = Clip(content: .text("검증"))
        try await spy.insert(sentinel)
        await assertEvents(stream, expected: [.inserted(sentinel)])
    }

    func testRejectedDeletionPreservesClipOriginalAndEvents() async throws {
        let spy = ClipImageRepositorySpy(repository: try makeRepository())
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: spy, files: files)
        let data = try ClipImageTestFixture.data()
        let result = try await service.saveImage(data)
        let stream = await spy.changes()
        await spy.reject(.delete)
        do {
            _ = try await service.delete(id: result.value.id)
            XCTFail("실패하도록 설정한 삭제 성공")
        } catch { XCTAssertEqual(error as? ClipRepositoryError, .writeFailed) }
        let preserved = try await spy.fetch(id: result.value.id)
        let original = try await service.loadImage(id: result.value.id)
        XCTAssertEqual(preserved, result.value)
        XCTAssertEqual(original, data)
        let sentinel = Clip(content: .text("검증"))
        try await spy.insert(sentinel)
        await assertEvents(stream, expected: [.inserted(sentinel)])
    }

    func testFailedInsertCompensationIsRecoveredWithoutLosingRepositoryError() async throws {
        let root = self.root
        let spy = ClipImageRepositorySpy(repository: try makeRepository(), beforeInsert: { clip in
            guard case .image(let image) = clip.content else { return }
            try ClipImageFileSystemTestFixture.makeReadOnly(root.appendingPathComponent(image.fileID.uuidString))
        })
        await spy.reject(.insert)
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: spy, files: files)
        do {
            _ = try await service.saveImage(ClipImageTestFixture.data())
            XCTFail("실패하도록 설정한 삽입 성공")
        } catch {
            if error is XCTSkip { throw error }
            XCTAssertEqual(error as? ClipRepositoryError, .writeFailed)
        }
        XCTAssertEqual(try files.pendingFileIDs().count, 1)
        try ClipImageFileSystemTestFixture.restorePermissions(at: root)
        let reopenedFiles = try ClipImageFileStore(rootURL: root)
        let reopened = ClipImageService(repository: spy, files: reopenedFiles)
        let pending = try await reopened.recoverPendingCleanup()
        XCTAssertEqual(pending, [])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testMarkerFailurePreventsMetadataDeletion() async throws {
        let repository = try makeRepository()
        let data = try ClipImageTestFixture.data()
        let service = ClipImageService(repository: repository, files: try ClipImageFileStore(rootURL: root))
        let result = try await service.saveImage(data)
        let files = try ClipImageFileStore(rootURL: root)
        let marker = root.appendingPathComponent(try image(in: result.value).fileID.uuidString).appendingPathComponent("pending")
        try FileManager.default.createDirectory(at: marker, withIntermediateDirectories: false)
        let failing = ClipImageService(repository: repository, files: files)
        do {
            _ = try await failing.delete(id: result.value.id)
            XCTFail("정리 후보 생성 실패 후 삭제 성공")
        } catch { XCTAssertEqual(error as? ClipImageFileError, .unsafePath) }
        let preserved = try await repository.fetch(id: result.value.id)
        XCTAssertEqual(preserved, result.value)
        XCTAssertEqual(try files.load(fileID: image(in: result.value).fileID), data)
    }

    func testCommittedDeletionWithFailedCleanupIsRecoveredAfterReopening() async throws {
        let repository = try makeRepository()
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: repository, files: files)
        let result = try await service.saveImage(ClipImageTestFixture.data())
        let metadata = try image(in: result.value)
        let directory = root.appendingPathComponent(metadata.fileID.uuidString)
        let spy = ClipImageRepositorySpy(repository: repository, beforeDelete: { _ in
            try ClipImageFileSystemTestFixture.makeReadOnly(directory)
        })
        let failing = ClipImageService(repository: spy, files: files)
        let stream = await repository.changes()
        let deleted = try await failing.delete(id: result.value.id)
        XCTAssertEqual(deleted.cleanup, .pending(metadata.fileID))
        let missing = try await repository.fetch(id: result.value.id)
        XCTAssertNil(missing)
        await assertEvents(stream, expected: [.deleted(result.value.id)])
        let reopenedFiles = try ClipImageFileStore(rootURL: root)
        XCTAssertEqual(try reopenedFiles.pendingFileIDs(), [metadata.fileID])
        let retry = try await failing.recoverPendingCleanup()
        XCTAssertEqual(retry, [metadata.fileID])
        try ClipImageFileSystemTestFixture.restorePermissions(at: root)
        let reopened = ClipImageService(repository: try makeRepository(), files: reopenedFiles)
        let pending = try await reopened.recoverPendingCleanup()
        XCTAssertEqual(pending, [])
        XCTAssertThrowsError(try reopenedFiles.load(fileID: metadata.fileID))
        XCTAssertEqual(try reopenedFiles.pendingFileIDs(), [])
    }

    func testFailedMarkerRemovalReportsCommittedSaveAndRecoveryPreservesReference() async throws {
        let repository = try makeRepository()
        let data = try ClipImageTestFixture.data()
        let root = self.root
        let spy = ClipImageRepositorySpy(repository: repository, beforeInsert: { clip in
            guard case .image(let image) = clip.content else { return }
            try ClipImageFileSystemTestFixture.makeReadOnly(root.appendingPathComponent(image.fileID.uuidString))
        })
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: spy, files: files)
        let result = try await service.saveImage(data)
        let metadata = try image(in: result.value)
        XCTAssertEqual(result.cleanup, .pending(metadata.fileID))
        try ClipImageFileSystemTestFixture.restorePermissions(at: root)
        let reopenedFiles = try ClipImageFileStore(rootURL: root)
        let reopened = ClipImageService(repository: repository, files: reopenedFiles)
        let pending = try await reopened.recoverPendingCleanup()
        XCTAssertEqual(pending, [])
        XCTAssertEqual(try reopenedFiles.load(fileID: metadata.fileID), data)
        XCTAssertEqual(try reopenedFiles.pendingFileIDs(), [])
    }

    func testFailedReferenceQueryKeepsCandidateAndOriginalUntilRetry() async throws {
        let spy = ClipImageRepositorySpy(repository: try makeRepository())
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: spy, files: files)
        let data = try ClipImageTestFixture.data()
        let result = try await service.saveImage(data)
        let metadata = try image(in: result.value)
        await spy.reject(.list)
        let deleted = try await service.delete(id: result.value.id)
        XCTAssertEqual(deleted.cleanup, .pending(metadata.fileID))
        do {
            _ = try await service.recoverPendingCleanup()
            XCTFail("실패하도록 설정한 참조 조회 후 복구 성공")
        } catch { XCTAssertEqual(error as? ClipRepositoryError, .readFailed) }
        XCTAssertEqual(try files.load(fileID: metadata.fileID), data)
        XCTAssertEqual(try files.pendingFileIDs(), [metadata.fileID])
        await spy.allow(.list)
        let pending = try await service.recoverPendingCleanup()
        XCTAssertEqual(pending, [])
        XCTAssertThrowsError(try files.load(fileID: metadata.fileID))
    }

    func testSharedOriginalIsRemovedOnlyAfterLastReference() async throws {
        let repository = try makeRepository()
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: repository, files: files)
        let data = try ClipImageTestFixture.data()
        let result = try await service.saveImage(data)
        let second = Clip(content: result.value.content)
        try await repository.insert(second)
        let firstDeletion = try await service.delete(id: result.value.id)
        XCTAssertEqual(firstDeletion.cleanup, .completed)
        XCTAssertEqual(try files.load(fileID: image(in: second).fileID), data)
        let lastDeletion = try await service.delete(id: second.id)
        XCTAssertEqual(lastDeletion.cleanup, .completed)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testRecoveryHandlesInterruptedDirectoriesWithoutDeletingCompletedStandaloneFile() async throws {
        let repository = try makeRepository()
        let files = try ClipImageFileStore(rootURL: root)
        let data = try ClipImageTestFixture.data()
        let orphan = try files.save(data)
        let completed = try files.save(data)
        try files.finishPending(fileID: completed.fileID)
        let empty = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: false)
        try Data("partial".utf8).write(to: empty.appendingPathComponent("temporary"))
        let service = ClipImageService(repository: repository, files: files)
        let pending = try await service.recoverPendingCleanup()
        XCTAssertEqual(pending, [])
        XCTAssertThrowsError(try files.load(fileID: orphan.fileID))
        XCTAssertFalse(FileManager.default.fileExists(atPath: empty.path))
        XCTAssertEqual(try files.load(fileID: completed.fileID), data)
    }

    func testRecoveryFinishesDeletionInterruptedBeforeOrAfterMarkerRemoval() async throws {
        let repository = try makeRepository()
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: repository, files: files)
        for removeMarker in [false, true] {
            let result = try await service.saveImage(ClipImageTestFixture.data())
            let metadata = try image(in: result.value)
            let directory = root.appendingPathComponent(metadata.fileID.uuidString)
            try files.markPending(fileID: metadata.fileID)
            try await repository.delete(id: result.value.id)
            try FileManager.default.removeItem(at: directory.appendingPathComponent("original"))
            if removeMarker { try files.finishPending(fileID: metadata.fileID) }
            let reopenedFiles = try ClipImageFileStore(rootURL: root)
            XCTAssertEqual(try reopenedFiles.pendingFileIDs(), [metadata.fileID])
            let reopened = ClipImageService(repository: try makeRepository(), files: reopenedFiles)
            let pending = try await reopened.recoverPendingCleanup()
            XCTAssertEqual(pending, [])
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        }
    }

    func testMissingOriginalDoesNotAutomaticallyDeleteMetadata() async throws {
        let repository = try makeRepository()
        let metadata = ClipImageMetadata(
            fileID: UUID(),
            contentType: "public.png",
            pixelWidth: 2,
            pixelHeight: 3,
            byteCount: 24
        )
        let clip = Clip(content: .image(metadata))
        try await repository.insert(clip)
        let service = ClipImageService(repository: repository, files: try ClipImageFileStore(rootURL: root))
        do {
            _ = try await service.loadImage(id: clip.id)
            XCTFail("없는 원본 불러오기 성공")
        } catch { XCTAssertEqual(error as? ClipImageFileError, .notFound(metadata.fileID)) }
        let preserved = try await repository.fetch(id: clip.id)
        XCTAssertEqual(preserved, clip)
        let deleted = try await service.delete(id: clip.id)
        XCTAssertEqual(deleted.cleanup, .completed)
    }

    func testConcurrentSavesAndRecoveryPreserveEveryCommittedOriginal() async throws {
        let spy = ClipImageRepositorySpy(repository: try makeRepository())
        await spy.yieldBeforeInsert()
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: spy, files: files)
        let data = try ClipImageTestFixture.data()
        let clips = try await withThrowingTaskGroup(of: Clip?.self) { group in
            for _ in 0..<12 {
                group.addTask { .some(try await service.saveImage(data).value) }
                group.addTask {
                    _ = try await service.recoverPendingCleanup()
                    return nil
                }
            }
            var clips = [Clip]()
            for try await clip in group { if let clip { clips.append(clip) } }
            return clips
        }
        XCTAssertEqual(clips.count, 12)
        for clip in clips { XCTAssertEqual(try files.load(fileID: image(in: clip).fileID), data) }
        XCTAssertEqual(try files.pendingFileIDs(), [])
    }

    func testCancelledSaveDoesNotCreateAnOriginalOrMetadata() async throws {
        let repository = try makeRepository()
        let files = try ClipImageFileStore(rootURL: root)
        let service = ClipImageService(repository: repository, files: files)
        let data = try ClipImageTestFixture.data()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.saveImage(data)
        }
        do {
            _ = try await task.value
            XCTFail("취소된 저장 성공")
        } catch { XCTAssertTrue(error is CancellationError) }
        let clips = try await repository.fetchAll(order: .createdAt)
        XCTAssertEqual(clips, [])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    private func makeRepository() throws -> SQLiteClipRepository {
        try SQLiteClipRepository(databaseURL: directory.appendingPathComponent("clips.sqlite"))
    }

    private func image(in clip: Clip) throws -> ClipImageMetadata {
        guard case .image(let metadata) = clip.content else { throw ClipImageFileError.notImage(clip.id) }
        return metadata
    }

    private func assertEvents(
        _ stream: AsyncStream<ClipRepositoryEvent>,
        expected: [ClipRepositoryEvent]
    ) async {
        let received = expectation(description: "확정된 DB 변경만 이벤트로 전달")
        let task = Task {
            var iterator = stream.makeAsyncIterator()
            for event in expected {
                let actual = await iterator.next()
                XCTAssertEqual(actual, event)
            }
            received.fulfill()
        }
        await fulfillment(of: [received], timeout: 2)
        task.cancel()
        await task.value
    }
}

private actor ClipImageRepositorySpy: ClipRepository {
    enum Operation: Hashable { case insert, delete, list }
    private let repository: SQLiteClipRepository
    private var rejected = Set<Operation>()
    private var yieldsBeforeInsert = false
    private let beforeInsert: @Sendable (Clip) throws -> Void
    private let beforeDelete: @Sendable (Clip.ID) throws -> Void

    init(
        repository: SQLiteClipRepository,
        beforeInsert: @escaping @Sendable (Clip) throws -> Void = { _ in },
        beforeDelete: @escaping @Sendable (Clip.ID) throws -> Void = { _ in }
    ) {
        self.repository = repository
        self.beforeInsert = beforeInsert
        self.beforeDelete = beforeDelete
    }
    func reject(_ operation: Operation) { rejected.insert(operation) }
    func allow(_ operation: Operation) { rejected.remove(operation) }
    func yieldBeforeInsert() { yieldsBeforeInsert = true }
    func fetchAll(order: ClipSortOrder) async throws -> [Clip] {
        if rejected.contains(.list) { throw ClipRepositoryError.readFailed }
        return try await repository.fetchAll(order: order)
    }
    func fetch(id: Clip.ID) async throws -> Clip? { try await repository.fetch(id: id) }
    func insert(_ clip: Clip) async throws {
        try beforeInsert(clip)
        if rejected.contains(.insert) { throw ClipRepositoryError.writeFailed }
        if yieldsBeforeInsert { await Task.yield() }
        try await repository.insert(clip)
    }
    func update(
        id: Clip.ID,
        change: ClipUpdate
    ) async throws -> Clip {
        try await repository.update(id: id, change: change)
    }
    func delete(id: Clip.ID) async throws {
        try beforeDelete(id)
        if rejected.contains(.delete) { throw ClipRepositoryError.writeFailed }
        try await repository.delete(id: id)
    }
    func changes() async -> AsyncStream<ClipRepositoryEvent> { await repository.changes() }
}
