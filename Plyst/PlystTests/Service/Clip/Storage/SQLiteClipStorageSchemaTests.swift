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

    func testStoreWithoutMigrationTableOpensAndKeepsUserVersion() async throws {
        let clip = Clip(content: .text("고정"), isPinned: true)
        let storage = try SQLiteClipStorageService(databaseURL: url)
        try await storage.insert(clip)
        let pinnedAt = try fetchPinnedAt()
        try execute("""
            DROP TABLE grdb_migrations;
            PRAGMA user_version = 3;
            """)
        let opened = try SQLiteClipStorageService(databaseURL: url)
        let restored = try await opened.fetch(id: clip.id)
        XCTAssertEqual(restored, clip)
        XCTAssertEqual(try fetchPinnedAt(), pinnedAt)
        XCTAssertEqual(try fetchMigrationIdentifiers(), ["CreateClipSearchTerms", "CreateClips"])
        XCTAssertEqual(try read { try Int.fetchOne($0, sql: "PRAGMA user_version") }, 3)
    }

    private func execute(_ sql: String) throws {
        let connection = try DatabaseQueue(path: url.path)
        try connection.write { try $0.execute(sql: sql) }
    }

    private func read<Value>(_ value: (Database) throws -> Value) throws -> Value {
        try DatabaseQueue(path: url.path).read(value)
    }

    /// createdAt 오름차순으로 반환합니다.
    private func fetchPinnedAt() throws -> [Double?] {
        try read { try Double?.fetchAll($0, sql: "SELECT pinnedAt FROM clips ORDER BY createdAt") }
    }

    private func fetchMigrationIdentifiers() throws -> [String] {
        try read { try String.fetchAll($0, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier") }
    }
}
