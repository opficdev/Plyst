//
//  SearchViewController+SearchViewDelegate.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import ReactorKit
import RxSwift
import UIKit

extension SearchViewController: SearchViewDelegate {
    func searchView(
        _ view: SearchView,
        didChangeQuery query: String
    ) {
        reactor.action.onNext(.changeQuery(query))
    }

    func searchViewDidSubmit(_ view: SearchView) {
        reactor.action.onNext(.submitQuery)
    }

    func searchViewDidCancel(_ view: SearchView) {
        navigationController?.popViewController(animated: true)
    }

    func searchView(
        _ view: SearchView,
        didSelectFilter filter: HomeFilter
    ) {
        reactor.action.onNext(.selectFilter(filter))
    }

    func searchView(
        _ view: SearchView,
        didSelectRecentTerm term: String
    ) {
        reactor.action.onNext(.selectRecentTerm(term))
    }

    func searchView(
        _ view: SearchView,
        didRemoveRecentTerm term: String
    ) {
        reactor.action.onNext(.removeRecentTerm(term))
    }

    func searchViewDidClearRecentTerms(_ view: SearchView) {
        reactor.action.onNext(.clearRecentTerms)
    }
}
