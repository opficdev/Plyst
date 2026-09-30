//
//  SearchViewable.swift
//  Plyst
//
//  Created by opfic on 10/1/26.
//

import UIKit

@MainActor
protocol SearchViewable: UIView {
    var layout: HomeGridLayout { get }
    var collectionView: UICollectionView { get }
    var textCellType: any HomeTextCellable.Type { get }
    var imageCellType: any HomeImageCellable.Type { get }
    var sectionHeaderType: any HomeSectionHeaderViewable.Type { get }

    func setOnChangeQuery(_ action: @escaping @MainActor (String) -> Void)
    func setOnSubmit(_ action: @escaping @MainActor () -> Void)
    func setOnCancel(_ action: @escaping @MainActor () -> Void)
    func setOnSelectFilter(_ action: @escaping @MainActor (HomeFilter) -> Void)
    func setOnSelectRecentTerm(_ action: @escaping @MainActor (String) -> Void)
    func setOnRemoveRecentTerm(_ action: @escaping @MainActor (String) -> Void)
    func setOnClearRecentTerms(_ action: @escaping @MainActor () -> Void)

    func focusSearchField()
    func setQuery(_ query: String)
    func setSelectedFilter(_ filter: HomeFilter)
    func reloadContent()
    func scrollToTop()

    func setRecent(
        terms: [String],
        message: String?,
        showsClear: Bool
    )

    func showRecent()
    func showResults()

    func showEmptyState(
        title: String,
        message: String
    )

    func showFeedback(
        message: String,
        isSuccess: Bool
    )

    func hideFeedback()
}
