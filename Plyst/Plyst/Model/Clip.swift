//
//  Clip.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

import Foundation

/// An immutable snapshot of a saved clip. Content and creation time do not change after insertion.
struct Clip: Equatable, Identifiable, Sendable {

    let id: UUID
    let content: ClipContent
    let name: String?
    let isPinned: Bool
    let memo: String?
    let createdAt: Date
    /// Nil until the clip has been successfully copied again.
    let lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        content: ClipContent,
        name: String? = nil,
        isPinned: Bool = false,
        memo: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.content = content
        self.name = name
        self.isPinned = isPinned
        self.memo = memo
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}
