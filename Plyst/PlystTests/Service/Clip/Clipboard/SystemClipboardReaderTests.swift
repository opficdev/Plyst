//
//  SystemClipboardReaderTests.swift
//  PlystTests
//
//  Created by opfic on 9/29/26.
//

import Foundation
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import Plyst

@MainActor
final class SystemClipboardReaderTests: XCTestCase {
    private var items = [[String: Any]]()

    override func setUpWithError() throws {
        try super.setUpWithError()
        items = UIPasteboard.general.items
    }

    override func tearDownWithError() throws {
        UIPasteboard.general.items = items
        try super.tearDownWithError()
    }

    func testImageWinsOverTextAndURLInTheSameItemWithoutChangingBytes() throws {
        let data = try ClipImageTestFixture.data(type: UTType.jpeg.identifier, orientation: 6)
        let url = try XCTUnwrap(URL(string: "https://example.com/image"))
        UIPasteboard.general.items = [[
            UTType.jpeg.identifier: data,
            UTType.utf8PlainText.identifier: "이미지 설명",
            UTType.url.identifier: url
        ]]

        let result = try SystemClipboardReader().read()

        XCTAssertEqual(result, .image(data))
    }

    func testImageInLaterItemDoesNotReplaceFirstURL() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/first"))
        UIPasteboard.general.items = [
            [UTType.url.identifier: url],
            [UTType.png.identifier: try ClipImageTestFixture.data()]
        ]

        let result = try SystemClipboardReader().read()

        XCTAssertEqual(result, .text(url.absoluteString))
    }

    func testImageInLaterItemDoesNotReplaceFirstText() throws {
        let text = " 첫 번째 원문\n "
        UIPasteboard.general.items = [
            [UTType.utf8PlainText.identifier: text],
            [UTType.png.identifier: try ClipImageTestFixture.data()]
        ]

        let result = try SystemClipboardReader().read()

        XCTAssertEqual(result, .text(text))
    }

    func testCorruptImageRepresentationDoesNotFallBackToURL() throws {
        let data = Data("손상된 이미지".utf8)
        let url = try XCTUnwrap(URL(string: "https://example.com/fallback"))
        UIPasteboard.general.items = [[
            UTType.png.identifier: data,
            UTType.url.identifier: url
        ]]

        let result = try SystemClipboardReader().read()

        // 이미지 검증은 저장 서비스의 책임이며 읽기 단계에서 URL로 대체하지 않습니다.
        XCTAssertEqual(result, .image(data))
    }

    func testAnimatedImageBytesAreReadWithoutReencoding() throws {
        let data = try ClipImageTestFixture.data(type: UTType.gif.identifier, count: 2)
        UIPasteboard.general.items = [[UTType.gif.identifier: data]]

        let result = try SystemClipboardReader().read()

        XCTAssertEqual(result, .image(data))
    }

    func testUnreadableImageRepresentationDoesNotFallBackToURL() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/fallback"))
        let provider = NSItemProvider(object: url as NSURL)
        provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
            completion(nil, NSError(domain: "PlystClipboardReaderTests", code: 1))
            return nil
        }
        UIPasteboard.general.itemProviders = [provider]

        XCTAssertEqual(try SystemClipboardReader().read(), .accessFailed)
    }

    func testEmptyPasteboardDoesNotProduceContent() throws {
        UIPasteboard.general.items = []

        XCTAssertEqual(try SystemClipboardReader().read(), .empty)
    }

    func testUnsupportedFirstItemDoesNotSelectLaterImage() throws {
        UIPasteboard.general.items = [
            [UTType.pdf.identifier: Data("%PDF".utf8)],
            [UTType.png.identifier: try ClipImageTestFixture.data()]
        ]

        XCTAssertEqual(try SystemClipboardReader().read(), .unsupported)
    }

    func testCancelledReadDoesNotReturnContent() async throws {
        UIPasteboard.general.items = [[UTType.png.identifier: try ClipImageTestFixture.data()]]
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try SystemClipboardReader().read()
        }

        do {
            _ = try await task.value
            XCTFail("취소된 클립보드 읽기 성공")
        } catch { XCTAssertTrue(error is CancellationError) }
    }
}
