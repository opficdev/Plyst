//
//  HomePinnedClipCell.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import UIKit

final class HomePinnedClipCell: UIView {
    static let width = CGFloat(228)
    static let height = CGFloat(76)
    static let thumbnailDimension = CGFloat(56)

    private static let nameFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
    private static let metadataFont = UIFont.monospacedSystemFont(ofSize: 9.5, weight: .medium)

    private let card = UIView()
    private let visualBox = UIView()
    private let thumbnailView = UIImageView()
    private let quote = UILabel()
    private let name = UILabel()
    private let metadata = UILabel()
    private lazy var textStack = UIStackView(arrangedSubviews: [name, metadata])

    private(set) var representedKey: HomeThumbnailKey?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        makeHierarchy()
        makeLayout()
        bindTraitChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateBorder()
    }

    func configure(
        clip: Clip,
        now: Date,
        key: HomeThumbnailKey?,
        thumbnail: UIImage?
    ) {
        switch clip.content {
        case .text(let text):
            representedKey = nil
            quote.isHidden = false
            thumbnailView.isHidden = true
            name.text = clip.name ?? text
            metadata.text = "텍스트 · \(HomeCardFormat.time(for: clip.createdAt, now: now))"

        case .image:
            representedKey = key
            quote.isHidden = true
            thumbnailView.isHidden = false
            thumbnailView.image = thumbnail
            name.text = clip.name ?? "이름 없는 이미지"
            metadata.text = "이미지 · \(HomeCardFormat.time(for: clip.createdAt, now: now))"
        }
    }

    private func configureAppearance() {
        card.backgroundColor = UIColor(resource: .homeCard)
        card.layer.masksToBounds = true
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1

        visualBox.backgroundColor = UIColor(resource: .homeImageBackground)
        visualBox.layer.masksToBounds = true
        visualBox.layer.cornerRadius = 10

        thumbnailView.contentMode = .scaleAspectFit

        quote.text = "“"
        quote.font = UIFont(name: "Georgia-Bold", size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
        quote.textColor = UIColor(resource: .homeMarkBackground)
        quote.textAlignment = .center

        name.font = Self.nameFont
        name.textColor = UIColor(resource: .homePrimaryText)
        name.lineBreakMode = .byTruncatingTail
        name.numberOfLines = 1

        metadata.font = Self.metadataFont
        metadata.textColor = UIColor(resource: .homeSecondaryText)
        metadata.lineBreakMode = .byTruncatingTail
        metadata.numberOfLines = 1

        textStack.axis = .vertical
        textStack.spacing = 4
    }

    private func makeHierarchy() {
        addSubview(card)
        card.addSubview(visualBox)
        visualBox.addSubview(thumbnailView)
        visualBox.addSubview(quote)
        card.addSubview(textStack)
    }

    private func makeLayout() {
        card.translatesAutoresizingMaskIntoConstraints = false
        visualBox.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        quote.translatesAutoresizingMaskIntoConstraints = false
        textStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            visualBox.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            visualBox.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            visualBox.widthAnchor.constraint(equalToConstant: Self.thumbnailDimension),
            visualBox.heightAnchor.constraint(equalToConstant: Self.thumbnailDimension),
            thumbnailView.topAnchor.constraint(equalTo: visualBox.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: visualBox.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: visualBox.trailingAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: visualBox.bottomAnchor),
            quote.centerXAnchor.constraint(equalTo: visualBox.centerXAnchor),
            quote.centerYAnchor.constraint(equalTo: visualBox.centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: visualBox.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
    }

    private func bindTraitChanges() {
        updateBorder()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: HomePinnedClipCell, _) in
            view.updateBorder()
        }
    }

    private func updateBorder() {
        card.layer.borderColor = UIColor(resource: .homeOutline).resolvedColor(with: traitCollection).cgColor
    }
}
