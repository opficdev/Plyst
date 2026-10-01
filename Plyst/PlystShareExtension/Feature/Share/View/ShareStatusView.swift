//
//  ShareStatusView.swift
//  PlystShareExtension
//
//  Created by opfic on 10/1/26.
//

import UIKit

@MainActor
final class ShareStatusView: UIView {
    private let stack = UIStackView()
    private let indicator = UIActivityIndicatorView(style: .medium)
    private let titleLabel = UILabel()
    private let button = UIButton(type: .system)
    private let send: @MainActor (ShareStatusViewAction) -> Void
    private var status = ShareStatus.saving

    init(
        frame: CGRect,
        send: @escaping @MainActor (ShareStatusViewAction) -> Void
    ) {
        self.send = send
        super.init(frame: frame)
        configureAppearance()
        makeHierarchy()
        makeLayout()
        bindActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func setStatus(_ status: ShareStatus) {
        self.status = status
        switch status {
        case .saving:
            indicator.startAnimating()
            titleLabel.text = "저장 중"
            button.setTitle("취소", for: .normal)
        case .completed:
            indicator.stopAnimating()
            titleLabel.text = "저장했습니다"
            button.setTitle("완료", for: .normal)
        case .failed:
            indicator.stopAnimating()
            titleLabel.text = "저장하지 못했습니다"
            button.setTitle("닫기", for: .normal)
        }
    }

    private func makeHierarchy() {
        stack.addArrangedSubview(indicator)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(button)
        addSubview(stack)
    }

    private func configureAppearance() {
        backgroundColor = .systemBackground
        titleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
    }

    private func makeLayout() {
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -32)
        ])
    }

    private func bindActions() {
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            send(status == .completed ? .done : .cancel)
        }, for: .touchUpInside)
    }
}
