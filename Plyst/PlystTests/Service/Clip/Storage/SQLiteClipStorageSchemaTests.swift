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

    func testIsPinnedSchemaIsConvertedWithoutNewMigrationIdentifiers() async throws {
        let pinned = Clip(
            content: .text("고정"),
            isPinned: true,
            createdAt: Date(timeIntervalSinceReferenceDate: 300)
        )
        let image = Clip(content: .image(ClipImageMetadata(
            fileID: UUID(),
            contentType: "public.png",
            pixelWidth: 640,
            pixelHeight: 480,
            byteCount: 4096
        )))
        let storage = try SQLiteClipStorageService(databaseURL: url)
        try await storage.insert(pinned)
        try await storage.insert(image)
        _ = try await storage.recordSearchTerm(XCTUnwrap(ClipSearchQuery("검색어")))
        let schema = try fetchClipsSchema()
        XCTAssertEqual(try fetchPinColumns(), ["pinnedAt"])
        try execute(Self.isPinnedSchemaSQL)
        XCTAssertEqual(try fetchPinColumns(), ["isPinned"])

        let converted = try SQLiteClipStorageService(databaseURL: url)
        let clips = try await converted.fetchAll(order: .createdAt)
        let history = try await converted.fetchSearchHistory()
        XCTAssertEqual(clips, [image, pinned])
        XCTAssertEqual(history.terms, ["검색어"])
        XCTAssertEqual(try fetchPinnedAt(), [300, nil])
        XCTAssertEqual(try fetchClipsSchema(), schema)
        XCTAssertEqual(try fetchMigrationIdentifiers(), ["CreateClipSearchTerms", "CreateClips"])

        _ = try SQLiteClipStorageService(databaseURL: url)
        XCTAssertEqual(try fetchClipsSchema(), schema)
        XCTAssertEqual(try fetchPinnedAt(), [300, nil])
    }

    func testFailedPinColumnConversionPreservesIsPinnedSchema() async throws {
        let storage = try SQLiteClipStorageService(databaseURL: url)
        try await storage.insert(Clip(content: .text("고정"), isPinned: true))
        try execute(Self.isPinnedSchemaSQL)
        try execute(#"CREATE TABLE "clipsRebuilt" ("id" TEXT)"#)
        XCTAssertThrowsError(try SQLiteClipStorageService(databaseURL: url)) {
            XCTAssertEqual($0 as? ClipStorageError, .writeFailed)
        }
        XCTAssertEqual(try fetchPinColumns(), ["isPinned"])
        XCTAssertEqual(try read { try String.fetchAll($0, sql: "SELECT text FROM clips") }, ["고정"])
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

    private func fetchPinColumns() throws -> [String] {
        try read {
            try String.fetchAll(
                $0,
                sql: "SELECT name FROM pragma_table_info('clips') WHERE name IN ('isPinned', 'pinnedAt')"
            )
        }
    }

    private func fetchClipsSchema() throws -> String? {
        try read { try String.fetchOne($0, sql: "SELECT sql FROM sqlite_master WHERE name = 'clips'") }
    }

    private func fetchMigrationIdentifiers() throws -> [String] {
        try read { try String.fetchAll($0, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier") }
    }

    /// pinnedAt 열을 도입하기 전의 clips 표로 되돌립니다.
    private static let isPinnedSchemaSQL = """
        CREATE TABLE "clipsLegacy" (
            "id" TEXT PRIMARY KEY NOT NULL,
            "kind" TEXT NOT NULL,
            "text" TEXT,
            "imageFileID" TEXT,
            "imageContentType" TEXT,
            "pixelWidth" INTEGER,
            "pixelHeight" INTEGER,
            "byteCount" INTEGER,
            "name" TEXT,
            "isPinned" INTEGER NOT NULL CHECK (("isPinned" = 0) OR ("isPinned" = 1)),
            "memo" TEXT,
            "createdAt" REAL NOT NULL,
            "lastUsedAt" REAL
        ) STRICT;
        INSERT INTO "clipsLegacy"
        SELECT "id", "kind", "text", "imageFileID", "imageContentType", "pixelWidth", "pixelHeight",
            "byteCount", "name", "pinnedAt" IS NOT NULL, "memo", "createdAt", "lastUsedAt"
        FROM "clips";
        DROP TABLE "clips";
        ALTER TABLE "clipsLegacy" RENAME TO "clips";
        """
}
