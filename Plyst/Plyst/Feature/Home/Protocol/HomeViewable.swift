//
//  HomeViewable.swift
//  Plyst
//
//  Created by opfic on 10/1/26.
//

import UIKit

@MainActor
protocol HomeViewable: UIView {
    var layout: HomeGridLayout { get }
    var collectionView: UICollectionView { get }
    var textCellType: any HomeTextCellable.Type { get }
    var imageCellType: any HomeImageCellable.Type { get }
    var sectionHeaderType: any HomeSectionHeaderViewable.Type { get }
    var pinnedRowType: any HomePinnedRowViewable.Type { get }

    func reloadContent()
    func updateScrollPosition(_ offset: CGFloat)
    func snapHeader()
    func setSaving(_ isSaving: Bool)
    func setSelectedFilter(_ filter: HomeFilter)
    func scrollToTop()

    func showEmptyState(
        title: String,
        message: String
    )

    func hideEmptyState()
}
