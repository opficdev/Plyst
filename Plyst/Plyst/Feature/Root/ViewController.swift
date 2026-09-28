//
//  ViewController.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

import ReactorKit
import RxSwift
import UIKit

final class ViewController: ReactorViewController<AppReactor> {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let action = UIAction { [weak self] _ in
            self?.reactor.action.onNext(.reload)
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .refresh, primaryAction: action)
        reactor.action.onNext(.viewDidLoad)
    }

    override func render(state: AppReactor.State) {
        view.isUserInteractionEnabled = state.isReady
    }
}
