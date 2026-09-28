//
//  ClipImageMetadata.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

import Foundation

struct ClipImageMetadata: Equatable, Sendable {

    /// An opaque identifier resolved by the image file service, not a path or file name.
    let fileID: UUID
    /// A uniform type identifier such as public.png.
    let contentType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int

    var isValid: Bool {
        !contentType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && 0 < pixelWidth
            && 0 < pixelHeight
            && 0 < byteCount
    }
}
