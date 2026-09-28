//
//  ClipRepositoryError.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

/// Repository failures independent of UI, persistence format, and file paths.
enum ClipRepositoryError: Error, Equatable, Sendable {

    case duplicateID(Clip.ID)
    case notFound(Clip.ID)
    case invalidContent
    case readFailed
    case writeFailed
    case corruptedData
}
