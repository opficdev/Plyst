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

    func setOnSave(_ action: @escaping @MainActor () -> Void)
    func setOnSearch(_ action: @escaping @MainActor () -> Void)
    func setOnSelectFilter(_ action: @escaping @MainActor (HomeFilter) -> Void)

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

    func showFeedback(
        message: String,
        isSuccess: Bool
    )

    func hideFeedback()
}
