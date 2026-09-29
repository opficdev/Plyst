//
//  SystemClipboardReader.swift
//  Plyst
//
//  Created by opfic on 9/29/26.
//

import UIKit

/// 첫 항목의 형식 확인과 읽기를 MainActor에서 수행합니다. 변경을 감시하거나 읽기를 재시도하지 않습니다.
struct SystemClipboardReader: ClipboardReader {
    @MainActor
    func read() throws -> ClipboardReadResult {
        try Task.checkCancellation()
        let pasteboard = UIPasteboard.general
        let changeCount = pasteboard.changeCount
        let result = readFirstItem(from: pasteboard)
        guard changeCount == pasteboard.changeCount else { return .accessFailed }
        return result
    }

    @MainActor
    private func readFirstItem(from pasteboard: UIPasteboard) -> ClipboardReadResult {
        guard pasteboard.numberOfItems != 0 else { return .empty }
        guard let textTypes = UIPasteboard.typeListString as? [String],
              let urlTypes = UIPasteboard.typeListURL as? [String] else { return .accessFailed }
        // hasStrings와 hasURLs는 전체 항목을 확인하므로 첫 항목의 형식만 검사합니다.
        let hasText = pasteboard.contains(pasteboardTypes: textTypes)
        let hasURL = pasteboard.contains(pasteboardTypes: urlTypes)
        guard hasText || hasURL else { return .unsupported }

        let text = hasText ? pasteboard.string : nil
        if let text, ClipContent.text(text).isValid { return .text(text) }
        if hasURL {
            guard let url = pasteboard.url else { return .accessFailed }
            return .text(url.absoluteString)
        }
        return text == nil ? .accessFailed : .empty
    }
}
