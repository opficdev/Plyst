//
//  SQLiteClipRecord.swift
//  Plyst
//
//  Created by opfic on 9/29/26.
//

import Foundation
import GRDB
import SQLiteData

/// 영구 저장 필드와 도메인 값을 분리합니다. 날짜는 기준 시각으로부터의 간격을 저장하여 정밀도를 보존합니다.
@Table("clips")
struct SQLiteClipRecord: Sendable {
    let id: UUID
    var kind: ContentKind
    var text: String?
    var imageFileID: UUID?
    var imageContentType: String?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var byteCount: Int?
    var name: String?
    /// 고정한 시각입니다. 새로 고정하면 저장하는 시점의 시각을 기록합니다.
    /// 고정을 유지하는 수정에서는 기존 값을 보존하고 고정을 해제하면 nil입니다. 고정 여부는 이 값의 유무로 판단합니다.
    var pinnedAt: Double?
    var memo: String?
    var createdAt: Double
    var lastUsedAt: Double?

    enum ContentKind: String, QueryBindable, Sendable {
        case text
        case image
    }
}

extension SQLiteClipRecord {

    /// pinnedAt은 고정된 클립에만 저장합니다. 고정 여부는 clip.isPinned만 따릅니다.
    init(
        _ clip: Clip,
        pinnedAt: Double
    ) {
        self.init(
            id: clip.id,
            kind: .text,
            name: clip.name,
            pinnedAt: clip.isPinned ? pinnedAt : nil,
            memo: clip.memo,
            createdAt: clip.createdAt.timeIntervalSinceReferenceDate,
            lastUsedAt: clip.lastUsedAt?.timeIntervalSinceReferenceDate
        )
        switch clip.content {
        case .text(let value):
            text = value
        case .image(let image):
            kind = .image
            imageFileID = image.fileID
            imageContentType = image.contentType
            pixelWidth = image.pixelWidth
            pixelHeight = image.pixelHeight
            byteCount = image.byteCount
        }
    }

    func clip() throws -> Clip {
        let content: ClipContent
        switch kind {
        case .text:
            guard let text, imageFileID == nil, imageContentType == nil,
                  pixelWidth == nil, pixelHeight == nil, byteCount == nil else {
                throw ClipStorageError.corruptedData
            }
            content = .text(text)
        case .image:
            guard text == nil, let imageFileID, let imageContentType, let pixelWidth, let pixelHeight, let byteCount else {
                throw ClipStorageError.corruptedData
            }
            content = .image(ClipImageMetadata(
                fileID: imageFileID, contentType: imageContentType,
                pixelWidth: pixelWidth, pixelHeight: pixelHeight, byteCount: byteCount
            ))
        }
        guard content.isValid, createdAt.isFinite, lastUsedAt?.isFinite != false, pinnedAt?.isFinite != false else {
            throw ClipStorageError.corruptedData
        }
        return Clip(
            id: id,
            content: content,
            name: name,
            isPinned: pinnedAt != nil,
            memo: memo,
            createdAt: Date(timeIntervalSinceReferenceDate: createdAt),
            lastUsedAt: lastUsedAt.map { Date(timeIntervalSinceReferenceDate: $0) }
        )
    }

    /// clips.sqlite의 모든 스키마 마이그레이션을 이 마이그레이터 하나에 등록합니다.
    /// 별도의 DatabaseMigrator를 만들면 hasBeenSuperseded 판정으로 기존 저장소가 corruptedData가 되므로, 새 마이그레이션은 이 목록 끝에 추가합니다.
    static func migrate(_ database: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        // React Native 버전이 새로 만든 DB에는 grdb_migrations 없이 표만 있으므로 기존 표를 다시 만들지 않습니다.
        migrator.registerMigration("CreateClips") { connection in
            guard try !connection.tableExists(tableName) else { return }
            try createTable(in: connection)
        }
        migrator.registerMigration("CreateClipSearchTerms") { connection in
            guard try !connection.tableExists(SQLiteClipSearchTermRecord.tableName) else { return }
            try SQLiteClipSearchTermRecord.createTable(in: connection)
        }
        if try database.read({ try migrator.hasBeenSuperseded($0) }) {
            throw ClipStorageError.corruptedData
        }
        try migrator.migrate(database)
    }

    private static func createTable(in connection: Database) throws {
        let columns = Self.columns
        try connection.create(table: tableName, options: .strict) { table in
            table.column(columns.id.name, .text).primaryKey().notNull()
            table.column(columns.kind.name, .text).notNull().check {
                $0 == ContentKind.text.rawValue || $0 == ContentKind.image.rawValue
            }
            table.column(columns.text.name, .text)
            table.column(columns.imageFileID.name, .text)
            table.column(columns.imageContentType.name, .text)
            table.column(columns.pixelWidth.name, .integer)
            table.column(columns.pixelHeight.name, .integer)
            table.column(columns.byteCount.name, .integer)
            table.column(columns.name.name, .text)
            table.column(columns.pinnedAt.name, .real)
            table.column(columns.memo.name, .text)
            table.column(columns.createdAt.name, .real).notNull()
            table.column(columns.lastUsedAt.name, .real)

            let kind = Column(columns.kind.name)
            let text = Column(columns.text.name)
            let imageFileID = Column(columns.imageFileID.name)
            let imageContentType = Column(columns.imageContentType.name)
            let pixelWidth = Column(columns.pixelWidth.name)
            let pixelHeight = Column(columns.pixelHeight.name)
            let byteCount = Column(columns.byteCount.name)
            let textContent = kind == ContentKind.text.rawValue && text != nil
                && imageFileID == nil && imageContentType == nil
                && pixelWidth == nil && pixelHeight == nil && byteCount == nil
            let imageContent = kind == ContentKind.image.rawValue && text == nil
                && imageFileID != nil && imageContentType != nil
                && pixelWidth != nil && 0 < pixelWidth
                && pixelHeight != nil && 0 < pixelHeight
                && byteCount != nil && 0 < byteCount
            table.check(textContent || imageContent)
        }
    }
}
