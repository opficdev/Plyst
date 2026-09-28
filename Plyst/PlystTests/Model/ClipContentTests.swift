//
//  ClipContentTests.swift
//  PlystTests
//
//  Created by opfic on 9/28/26.
//

import Foundation
import XCTest
@testable import Plyst

final class ClipContentTests: XCTestCase {

    func testEmptyAndWhitespaceOnlyTextIsInvalid() {
        for text in ["", "   ", "\n\r\t "] {
            XCTAssertFalse(ClipContent.text(text).isValid)
        }
    }

    func testURLTextKeepsItsOriginalWhitespace() {
        let text = " \nhttps://example.com/path?query=value\t "
        let content = ClipContent.text(text)

        XCTAssertTrue(content.isValid)
        XCTAssertEqual(content, .text(text))
    }

    func testImageMetadataRejectsMissingTypeAndNonpositiveDimensionsOrSize() {
        let images = [
            makeImage(contentType: ""),
            makeImage(contentType: " \n"),
            makeImage(pixelWidth: 0),
            makeImage(pixelWidth: -1),
            makeImage(pixelHeight: 0),
            makeImage(pixelHeight: -1),
            makeImage(byteCount: 0),
            makeImage(byteCount: -1)
        ]

        for image in images {
            XCTAssertFalse(ClipContent.image(image).isValid)
        }
        XCTAssertTrue(ClipContent.image(makeImage()).isValid)
    }

    private func makeImage(
        contentType: String = "public.png",
        pixelWidth: Int = 640,
        pixelHeight: Int = 480,
        byteCount: Int = 4096
    ) -> ClipImageMetadata {
        ClipImageMetadata(
            fileID: UUID(),
            contentType: contentType,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            byteCount: byteCount
        )
    }
}
