//
//  ClipShareServiceTests.swift
//  PlystTests
//
//  Created by opfic on 10/1/26.
//

import Foundation
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import Plyst

@MainActor
final class ClipShareServiceTests: XCTestCase {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Plyst-share-\(UUID())", isDirectory: true)
    private var url: URL { directory.appendingPathComponent("ShareInbox.sqlite") }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try super.tearDownWithError()
    }

    func testTextProviderIsSavedAsTextClipWithTrimmedTitle() async throws {
        let storage = try makeStorage()
        let text = " \n한글 'text'\t🙂 "
        let item = makeItem(providers: [NSItemProvider(object: text as NSString)], title: "  공유 제목 \n")

        let result = try await ClipShareService(storage: storage).saveText(item)

        let clip = try savedClip(result)
        XCTAssertEqual(clip.content, .text(text))
        XCTAssertEqual(clip.name, "공유 제목")
        XCTAssertNil(clip.memo)
        XCTAssertFalse(clip.isPinned)
        let stored = try await storage.fetchAll(order: .createdAt)
        XCTAssertEqual(stored, [clip])
    }

    func testURLProviderIsSavedAsTextClipWithOriginalString() async throws {
        let storage = try makeStorage()
        let original = "https://example.com/a%20b?query=value#section"
        let item = makeItem(providers: [NSItemProvider(object: try XCTUnwrap(URL(string: original)) as NSURL)])

        let result = try await ClipShareService(storage: storage).saveText(item)

        let clip = try savedClip(result)
        XCTAssertEqual(clip.content, .text(original))
        XCTAssertNil(clip.name)
        XCTAssertTrue(clip.content.isWebLink)
    }

    func testTextItemRegisteredAsObjectIsSavedLikeSafariSelection() async throws {
        let storage = try makeStorage()
        let text = "Safari에서 선택한 텍스트"
        let provider = NSItemProvider(item: text as NSString, typeIdentifier: UTType.plainText.identifier)
        let item = makeItem(providers: [provider])

        let result = try await ClipShareService(storage: storage).saveText(item)

        XCTAssertEqual(try savedClip(result).content, .text(text))
    }

    func testURLItemRegisteredAsObjectIsSavedAsOriginalString() async throws {
        let storage = try makeStorage()
        let original = "https://example.com/path?query=한글#section"
        let url = try XCTUnwrap(URL(string: original))
        let provider = NSItemProvider(item: url as NSURL, typeIdentifier: UTType.url.identifier)
        let item = makeItem(providers: [provider])

        let result = try await ClipShareService(storage: storage).saveText(item)

        XCTAssertEqual(try savedClip(result).content, .text(url.absoluteString))
    }

    func testTextIsPreferredWhenProviderOffersTextAndURL() async throws {
        let storage = try makeStorage()
        let provider = NSItemProvider(object: "페이지 제목" as NSString)
        provider.registerObject(try XCTUnwrap(URL(string: "https://example.com")) as NSURL, visibility: .all)
        let item = makeItem(providers: [provider])

        let result = try await ClipShareService(storage: storage).saveText(item)

        XCTAssertEqual(try savedClip(result).content, .text("페이지 제목"))
    }

    func testOnlyFirstSupportedProviderIsSaved() async throws {
        let storage = try makeStorage()
        let item = makeItem(providers: [
            NSItemProvider(object: UIImage()),
            NSItemProvider(object: "첫 텍스트" as NSString),
            NSItemProvider(object: "둘째 텍스트" as NSString)
        ])

        let result = try await ClipShareService(storage: storage).saveText(item)

        XCTAssertEqual(try savedClip(result).content, .text("첫 텍스트"))
        let stored = try await storage.fetchAll(order: .createdAt)
        XCTAssertEqual(stored.count, 1)
    }

    func testMissingOrUnsupportedAttachmentsReturnEmptyWithoutRecord() async throws {
        let storage = try makeStorage()
        let service = ClipShareService(storage: storage)

        let missing = try await service.saveText(ClipShareItem(item: nil))
        let unsupported = try await service.saveText(makeItem(providers: [NSItemProvider(object: UIImage())]))

        XCTAssertEqual(missing, .empty)
        XCTAssertEqual(unsupported, .empty)
        let stored = try await storage.fetchAll(order: .createdAt)
        XCTAssertTrue(stored.isEmpty)
    }

    func testWhitespaceOnlyTextReturnsEmptyWithoutRecord() async throws {
        let storage = try makeStorage()
        let item = makeItem(providers: [NSItemProvider(object: " \n\t " as NSString)])

        let result = try await ClipShareService(storage: storage).saveText(item)

        XCTAssertEqual(result, .empty)
        let stored = try await storage.fetchAll(order: .createdAt)
        XCTAssertTrue(stored.isEmpty)
    }

    func testBlankTitleBecomesNilName() async throws {
        let storage = try makeStorage()
        let item = makeItem(providers: [NSItemProvider(object: "본문" as NSString)], title: " \n ")

        let result = try await ClipShareService(storage: storage).saveText(item)

        XCTAssertNil(try savedClip(result).name)
    }

    func testLoadFailureReturnsLoadFailedWithoutRecordAndCanBeRetried() async throws {
        let storage = try makeStorage()
        let provider = NSItemProvider()
        provider.registerObject(ofClass: NSString.self, visibility: .all) { completion in
            completion(nil, CocoaError(.fileReadUnknown))
            return nil
        }
        let item = makeItem(providers: [provider])
        let service = ClipShareService(storage: storage)

        let first = try await service.saveText(item)
        let second = try await service.saveText(item)

        XCTAssertEqual(first, .loadFailed)
        XCTAssertEqual(second, .loadFailed)
        let stored = try await storage.fetchAll(order: .createdAt)
        XCTAssertTrue(stored.isEmpty)
    }

    func testStorageFailurePropagatesWithoutRecord() async throws {
        let storage = try makeStorage()
        let spy = ClipClipboardStorageServiceSpy(
            storage: storage,
            beforeInsert: { throw ClipStorageError.writeFailed }
        )
        let item = makeItem(providers: [NSItemProvider(object: "저장 실패" as NSString)])

        do {
            _ = try await ClipShareService(storage: spy).saveText(item)
            XCTFail("저장소 오류 전파 누락")
        } catch {
            XCTAssertEqual(error as? ClipStorageError, .writeFailed)
        }

        let stored = try await storage.fetchAll(order: .createdAt)
        XCTAssertTrue(stored.isEmpty)
    }

    func testCancelledTaskThrowsCancellationWithoutRecord() async throws {
        let storage = try makeStorage()
        let item = makeItem(providers: [NSItemProvider(object: "취소 전 텍스트" as NSString)])
        let service = ClipShareService(storage: storage)

        let task = Task {
            try await service.saveText(item)
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("취소 전파 누락")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let stored = try await storage.fetchAll(order: .createdAt)
        XCTAssertTrue(stored.isEmpty)
    }

    private func makeStorage() throws -> SQLiteClipStorageService {
        try SQLiteClipStorageService(databaseURL: url)
    }

    private func makeItem(
        providers: [NSItemProvider],
        title: String? = nil
    ) -> ClipShareItem {
        let extensionItem = NSExtensionItem()
        extensionItem.attachments = providers
        if let title {
            extensionItem.attributedTitle = NSAttributedString(string: title)
        }
        return ClipShareItem(item: extensionItem)
    }

    private func savedClip(_ result: ClipShareSaveResult) throws -> Clip {
        guard case .saved(let clip) = result else {
            XCTFail("저장 성공 결과 누락")
            throw ClipShareTestError.unexpectedResult
        }
        return clip
    }
}

private enum ClipShareTestError: Error {
    case unexpectedResult
}
