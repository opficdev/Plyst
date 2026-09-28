//
//  ClipRepositoryEvent.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

/// A committed metadata change. Inserted and updated values contain the complete committed snapshot.
enum ClipRepositoryEvent: Equatable, Sendable {

    case inserted(Clip)
    case updated(Clip)
    case deleted(Clip.ID)
}
