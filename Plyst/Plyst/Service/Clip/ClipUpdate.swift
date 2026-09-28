//
//  ClipUpdate.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

import Foundation

enum ClipUpdate: Equatable, Sendable {

    /// Replaces editable details together. Nil clears the corresponding optional value.
    case details(name: String?, memo: String?, isPinned: Bool)
    /// Updates usage independently so saving an editing draft cannot overwrite a newer usage timestamp.
    case lastUsedAt(Date)

    /// Apply to the latest stored clip inside the repository's serialized write operation.
    func applying(to clip: Clip) -> Clip {
        switch self {
        case let .details(name, memo, isPinned):
            return Clip(
                id: clip.id,
                content: clip.content,
                name: name,
                isPinned: isPinned,
                memo: memo,
                createdAt: clip.createdAt,
                lastUsedAt: clip.lastUsedAt
            )
        case .lastUsedAt(let date):
            return Clip(
                id: clip.id,
                content: clip.content,
                name: clip.name,
                isPinned: clip.isPinned,
                memo: clip.memo,
                createdAt: clip.createdAt,
                lastUsedAt: date
            )
        }
    }
}
