//
//  ThumbnailImageCache+HomeThumbnailKey.swift
//  Plyst
//
//  Created by opfic on 10/1/26.
//

import UIKit

extension ThumbnailImageCache {
    func image(
        for key: HomeThumbnailKey,
        data: Data?
    ) -> UIImage? {
        image(
            fileID: key.fileID,
            maximumPixelDimension: key.maximumPixelDimension,
            data: data
        )
    }
}
