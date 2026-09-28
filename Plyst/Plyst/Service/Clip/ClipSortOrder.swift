//
//  ClipSortOrder.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

import Foundation

enum ClipSortOrder: Equatable, Sendable {

    case createdAt
    case lastUsedAt

    /// Descending timestamps, then creation time and ascending identifier for deterministic ties.
    /// Clips without usage history follow all used clips when sorting by lastUsedAt.
    func sorted(_ clips: [Clip]) -> [Clip] {
        clips.sorted { lhs, rhs in
            if self == .lastUsedAt, lhs.lastUsedAt != rhs.lastUsedAt {
                switch (lhs.lastUsedAt, rhs.lastUsedAt) {
                case let (lhsDate?, rhsDate?):
                    return rhsDate < lhsDate
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                }
            }
            if lhs.createdAt != rhs.createdAt {
                return rhs.createdAt < lhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
