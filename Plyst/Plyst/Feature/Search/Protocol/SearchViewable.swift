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
}
