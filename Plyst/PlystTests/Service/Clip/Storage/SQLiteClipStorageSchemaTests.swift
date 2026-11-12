//
//  SQLiteClipStorageSchemaTests.swift
//  PlystTests
//
//  Created by opfic on 11/12/26.
//

import Foundation
import SQLiteData
import XCTest
@testable import Plyst

/// React Native 버전과 같은 pinnedAt 스키마와 기존 isPinned 스키마의 변환을 검증합니다.
final class SQLiteClipStorageSchemaTests: XCTestCase {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Plyst-\(UUID())", isDirectory: true)
    private var url: URL { directory.appendingPathComponent("clips.sqlite") }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try super.tearDownWithError()
    }

    func testPinnedAtIsRecordedPreservedAndClearedByPinState() async throws {
        let storage = try SQLiteClipStorageService(databaseURL: url)
        let clip = Clip(content: .text("원문"), isPinned: true)
        let start = Date().timeIntervalSinceReferenceDate
        try await storage.insert(clip)
        let end = Date().timeIntervalSinceReferenceDate
        let pinnedAt = try XCTUnwrap(fetchPinnedAt().first ?? nil)
        XCTAssertTrue(start <= pinnedAt && pinnedAt <= end)
        _ = try await storage.update(id: clip.id, change: .details(name: "이름", memo: "메모", isPinned: true))
        _ = try await storage.update(id: clip.id, change: .lastUsedAt(Date(timeIntervalSinceReferenceDate: 800)))
        XCTAssertEqual(try fetchPinnedAt(), [pinnedAt])
        _ = try await storage.update(id: clip.id, change: .details(name: "이름", memo: "메모", isPinned: false))
        XCTAssertEqual(try fetchPinnedAt(), [nil])
    }

    private func read<Value>(_ value: (Database) throws -> Value) throws -> Value {
        try DatabaseQueue(path: url.path).read(value)
    }

    /// createdAt 오름차순으로 반환합니다.
    private func fetchPinnedAt() throws -> [Double?] {
        try read { try Double?.fetchAll($0, sql: "SELECT pinnedAt FROM clips ORDER BY createdAt") }
    }
}
