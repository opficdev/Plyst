//
//  HomeHeaderView.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import UIKit

final class HomeTitleHeaderView: UIView {
    private let mark = UILabel()
    private let title = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        makeHierarchy()
        makeLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    private func configureAppearance() {
        mark.attributedText = NSAttributedString(string: "P", attributes: [.kern: -0.72])
        mark.font = .systemFont(ofSize: 18, weight: .heavy)
        mark.textAlignment = .center
        mark.textColor = UIColor(resource: .homeBottomText)
        mark.backgroundColor = UIColor(resource: .homeMarkBackground)
        mark.layer.cornerRadius = 10

        title.attributedText = NSAttributedString(string: "Plyst", attributes: [.kern: -1.12])
        title.font = .systemFont(ofSize: 32, weight: .heavy)
        title.textColor = UIColor(resource: .homePrimaryText)
    }

    private func makeHierarchy() {
        addSubview(mark)
        addSubview(title)
    }

    private func makeLayout() {
        mark.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mark.topAnchor.constraint(equalTo: topAnchor),
            mark.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            mark.widthAnchor.constraint(equalToConstant: 34),
            mark.heightAnchor.constraint(equalToConstant: 34),
            title.centerYAnchor.constraint(equalTo: mark.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: mark.trailingAnchor, constant: 10),
            title.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            bottomAnchor.constraint(equalTo: title.bottomAnchor, constant: 16)
        ])
    }
}

final class HomeSectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = String(describing: HomeSectionHeaderView.self)

    private let title = UILabel()
    private let rule = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        makeHierarchy()
        makeLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func configure(title: String) {
        self.title.attributedText = NSAttributedString(
            string: title,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor(resource: .homeSecondaryText),
                .kern: 0.88
            ]
        )
    }

    private func configureAppearance() {
        rule.backgroundColor = UIColor(resource: .homeOutline)
    }

    private func makeHierarchy() {
        addSubview(title)
        addSubview(rule)
    }

    private func makeLayout() {
        title.translatesAutoresizingMaskIntoConstraints = false
        rule.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            rule.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            rule.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 10),
            rule.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            rule.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
}
