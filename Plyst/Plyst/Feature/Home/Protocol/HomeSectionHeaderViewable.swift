//
//  HomeSectionHeaderViewable.swift
//  Plyst
//
//  Created by opfic on 10/1/26.
//

import UIKit

@MainActor
protocol HomeSectionHeaderViewable: UICollectionReusableView, ReuseIdentifiable {
    func configure(title: String)
}
