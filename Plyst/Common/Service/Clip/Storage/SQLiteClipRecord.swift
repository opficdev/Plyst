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

    /// clips.sqlite와 ShareInbox.sqlite의 스키마 마이그레이션을 이 마이그레이터 하나에 등록합니다.
    /// 별도의 DatabaseMigrator를 만들면 hasBeenSuperseded 판정으로 기존 저장소가 corruptedData가 됩니다.
    /// React Native 버전은 CreateClips와 CreateClipSearchTerms 외의 식별자를 손상으로 판단합니다. 새 마이그레이션 식별자를 추가하지 않고 열 구성으로 대상을 판정하여 스키마를 변환합니다.
    static func migrate(_ database: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        // React Native 버전이 새로 만든 DB에는 grdb_migrations 없이 표만 있으므로 기존 표를 다시 만들지 않습니다.
        migrator.registerMigration("CreateClips") { connection in
            guard try !connection.tableExists(tableName) else { return }
            try createTable(
                named: tableName,
                in: connection
            )
        }
        migrator.registerMigration("CreateClipSearchTerms") { connection in
            guard try !connection.tableExists(SQLiteClipSearchTermRecord.tableName) else { return }
            try SQLiteClipSearchTermRecord.createTable(in: connection)
        }
        if try database.read({ try migrator.hasBeenSuperseded($0) }) {
            throw ClipStorageError.corruptedData
        }
        try migrator.migrate(database)
        try convertPinColumn(in: database)
    }

    /// isPinned 열로 만든 clips 표를 React Native 버전과 같은 pinnedAt 열로 재구성합니다.
    /// 기존 DB는 고정한 시각을 기록하지 않았으므로 고정된 클립의 pinnedAt에는 createdAt을 넣습니다.
    /// 재구성은 쓰기 트랜잭션 하나에서 수행합니다. 실패하면 기존 표가 그대로 남습니다.
    private static func convertPinColumn(in database: DatabaseQueue) throws {
        // 열 때마다 쓰기 잠금을 잡지 않도록 읽기로 먼저 판정합니다.
        guard try database.read({ try hasIsPinnedColumn(in: $0) }) else { return }
        try database.write { connection in
            // ShareInbox.sqlite는 다른 프로세스가 먼저 변환할 수 있어 쓰기 잠금 안에서 다시 판정합니다.
            guard try hasIsPinnedColumn(in: connection) else { return }
            let rebuiltTableName = "\(tableName)Rebuilt"
            try createTable(
                named: rebuiltTableName,
                in: connection
            )
            try connection.execute(sql: """
                INSERT INTO "\(rebuiltTableName)" (
                    "id", "kind", "text", "imageFileID", "imageContentType", "pixelWidth", "pixelHeight",
                    "byteCount", "name", "pinnedAt", "memo", "createdAt", "lastUsedAt"
                )
                SELECT
                    "id", "kind", "text", "imageFileID", "imageContentType", "pixelWidth", "pixelHeight",
                    "byteCount", "name", CASE WHEN "isPinned" = 1 THEN "createdAt" END, "memo", "createdAt", "lastUsedAt"
                FROM "\(tableName)"
                """)
            try connection.drop(table: tableName)
            try connection.rename(table: rebuiltTableName, to: tableName)
        }
    }

    /// GRDB 스키마 캐시를 거치지 않도록 pragma_table_info를 직접 조회합니다.
    private static func hasIsPinnedColumn(in connection: Database) throws -> Bool {
        let names = try Set(String.fetchAll(
            connection,
            sql: "SELECT name FROM pragma_table_info(?)",
            arguments: [tableName]
        ))
        return names.contains("isPinned") && !names.contains(columns.pinnedAt.name)
    }

    private static func createTable(
        named name: String,
        in connection: Database
    ) throws {
        let columns = Self.columns
        try connection.create(table: name, options: .strict) { table in
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
