//
//  HomePinnedRowViewable.swift
//  Plyst
//
//  Created by opfic on 10/1/26.
//

import UIKit

@MainActor
protocol HomePinnedRowViewable: UICollectionReusableView, ReuseIdentifiable {
    static var height: CGFloat { get }
    static var thumbnailDimension: CGFloat { get }

    func setOnScroll(_ action: @escaping @MainActor (any HomePinnedRowViewable) -> Void)

    func configure(
        clips: [Clip],
        now: Date,
        key: (Clip) -> HomeThumbnailKey?,
        thumbnail: (HomeThumbnailKey) -> UIImage?
    )

    func visibleClips() -> [Clip]
}
