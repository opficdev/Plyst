//
//  HomePinnedRowView.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import UIKit

final class HomePinnedRowView: UICollectionReusableView {
    static let reuseIdentifier = String(describing: HomePinnedRowView.self)
    private static let titleTopInset = CGFloat(20)
    private static let rowTopInset = CGFloat(14)
    private static let bottomInset = CGFloat(16)
    private static let titleFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .semibold)

    static var height: CGFloat {
        titleTopInset + ceil(titleFont.lineHeight) + rowTopInset + HomePinnedClipCell.height + bottomInset
    }

    private let title = UILabel()
    private let rule = UIView()
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var cells = [HomePinnedClipCell]()

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

    func configure(
        clips: [Clip],
        now: Date,
        key: (Clip) -> HomeThumbnailKey?,
        thumbnail: (HomeThumbnailKey) -> UIImage?
    ) {
        while cells.count < clips.count { cells.append(makeCell()) }
        while clips.count < cells.count { cells.removeLast().removeFromSuperview() }

        for (index, clip) in clips.enumerated() {
            let clipKey = key(clip)
            cells[index].configure(
                clip: clip,
                now: now,
                key: clipKey,
                thumbnail: clipKey.flatMap(thumbnail)
            )
        }
    }

    private func makeCell() -> HomePinnedClipCell {
        let cell = HomePinnedClipCell()
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.widthAnchor.constraint(equalToConstant: HomePinnedClipCell.width).isActive = true
        stack.addArrangedSubview(cell)
        return cell
    }

    private func configureAppearance() {
        title.attributedText = NSAttributedString(
            string: "고정",
            attributes: [
                .font: Self.titleFont,
                .foregroundColor: UIColor(resource: .homeSecondaryText),
                .kern: 0.88
            ]
        )
        rule.backgroundColor = UIColor(resource: .homeOutline)
        scrollView.showsHorizontalScrollIndicator = false
        stack.axis = .horizontal
        stack.spacing = 10
    }

    private func makeHierarchy() {
        addSubview(title)
        addSubview(rule)
        addSubview(scrollView)
        scrollView.addSubview(stack)
    }

    private func makeLayout() {
        title.translatesAutoresizingMaskIntoConstraints = false
        rule.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: Self.titleTopInset),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            rule.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            rule.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 10),
            rule.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            rule.heightAnchor.constraint(equalToConstant: 1),
            scrollView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: Self.rowTopInset),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: HomePinnedClipCell.height),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
}
