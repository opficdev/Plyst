//
//  ClipContent.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

import Foundation

enum ClipContent: Equatable, Sendable {

    /// Stores the original string, including URLs, without normalization.
    case text(String)
    case image(ClipImageMetadata)

    /// Checks metadata only. Image decoding and file existence belong to the image file service.
    var isValid: Bool {
        switch self {
        case .text(let text):
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image(let image):
            return image.isValid
        }
    }
}
