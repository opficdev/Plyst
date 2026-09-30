//
//  HomeClipCell.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import UIKit

final class HomeTextCell: UICollectionViewCell {
    static let reuseIdentifier = String(describing: HomeTextCell.self)

    private static let nameFont = UIFont.systemFont(ofSize: 14.5, weight: .semibold)
    private static let bodyFont = UIFont.systemFont(ofSize: 14.5)
    private static let metadataFont = UIFont.monospacedSystemFont(ofSize: 10.5, weight: .medium)

    private let card = UIView()
    private let quote = UILabel()
    private let name = UILabel()
    private let body = UILabel()
    private let metadata = UILabel()
    private lazy var stack = UIStackView(arrangedSubviews: [quote, name, body, metadata])

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

    func configure(
        with clip: Clip,
        now: Date
    ) {
        guard case .text(let text) = clip.content else { return }
        name.text = clip.name
        name.isHidden = clip.name == nil
        body.text = text
        body.numberOfLines = clip.name == nil ? 3 : 2
        metadata.text = "텍스트 \(HomeCardFormat.time(for: clip.createdAt, now: now))"
    }

    static func height(
        for clip: Clip,
        width: CGFloat
    ) -> CGFloat {
        guard case .text(let text) = clip.content else { return 0 }
        let available = width - 26
        let bodyHeight = HomeCardFormat.height(
            for: text,
            font: bodyFont,
            width: available,
            lines: clip.name == nil ? 3 : 2
        )
        let nameHeight = clip.name.map {
            HomeCardFormat.height(for: $0, font: nameFont, width: available, lines: 2) + 6
        } ?? 0
        return 14 + 26 + 6 + nameHeight + bodyHeight + 10 + ceil(metadataFont.lineHeight) + 12
    }

    private func configureAppearance() {
        card.backgroundColor = UIColor(resource: .homeCard)
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.masksToBounds = true

        quote.text = "“"
        quote.font = UIFont(name: "Georgia-Bold", size: 26) ?? .systemFont(ofSize: 26, weight: .bold)
        quote.textColor = UIColor(resource: .homePrimaryText)

        name.font = Self.nameFont
        name.textColor = UIColor(resource: .homePrimaryText)
        name.numberOfLines = 2

        body.font = Self.bodyFont
        body.textColor = UIColor(resource: .homePrimaryText)
        body.numberOfLines = 3

        metadata.font = Self.metadataFont
        metadata.textColor = UIColor(resource: .homeSecondaryText)
        metadata.lineBreakMode = .byTruncatingTail
        metadata.numberOfLines = 1

        stack.axis = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(10, after: body)
    }

    private func makeHierarchy() {
        contentView.addSubview(card)
        card.addSubview(stack)
    }

    private func makeLayout() {
        card.translatesAutoresizingMaskIntoConstraints = false
        quote.heightAnchor.constraint(equalToConstant: 26).isActive = true
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
    }

    private func bindTraitChanges() {
        updateBorder()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (cell: HomeTextCell, _) in
            cell.updateBorder()
        }
    }

    private func updateBorder() {
        card.layer.borderColor = UIColor(resource: .homeOutline).resolvedColor(with: traitCollection).cgColor
    }
}

final class HomeImageCell: UICollectionViewCell {
    static let reuseIdentifier = String(describing: HomeImageCell.self)

    private static let nameFont = UIFont.systemFont(ofSize: 14.5, weight: .semibold)
    private static let metadataFont = UIFont.monospacedSystemFont(ofSize: 10.5, weight: .medium)

    private let card = UIView()
    private let imageBox = UIView()
    private let imageView = UIImageView()
    private let placeholder = UIImageView(image: UIImage(systemName: "photo"))
    private let name = UILabel()
    private let metadata = UILabel()

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

    override func prepareForReuse() {
        super.prepareForReuse()
        representedKey = nil
        setThumbnail(nil)
    }

    func configure(
        with clip: Clip,
        now: Date,
        key: HomeThumbnailKey,
        thumbnail: UIImage?
    ) {
        guard case .image(let image) = clip.content else { return }
        representedKey = key
        name.text = clip.name ?? "이름 없는 이미지"
        name.textColor = clip.name == nil ? UIColor(resource: .homeSecondaryText) : UIColor(resource: .homePrimaryText)
        metadata.text = "이미지 \(image.pixelWidth)×\(image.pixelHeight) \(HomeCardFormat.time(for: clip.createdAt, now: now))"
        setThumbnail(thumbnail)
    }

    func setThumbnail(_ thumbnail: UIImage?) {
        imageView.image = thumbnail
        placeholder.isHidden = thumbnail != nil
    }

    static func height(
        for clip: Clip,
        width: CGFloat
    ) -> CGFloat {
        let text = clip.name ?? "이름 없는 이미지"
        let nameHeight = HomeCardFormat.height(for: text, font: nameFont, width: width - 26, lines: 2)
        return 6 + (width - 12) + 10 + nameHeight + 10 + ceil(metadataFont.lineHeight) + 12
    }

    private func configureAppearance() {
        card.backgroundColor = UIColor(resource: .homeCard)
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.masksToBounds = true

        imageBox.backgroundColor = UIColor(resource: .homeImageBackground)
        imageBox.layer.cornerRadius = 13
        imageBox.layer.masksToBounds = true

        imageView.contentMode = .scaleAspectFit

        placeholder.tintColor = UIColor(resource: .homeSecondaryText)
        placeholder.contentMode = .scaleAspectFit

        name.font = Self.nameFont
        name.textColor = UIColor(resource: .homePrimaryText)
        name.numberOfLines = 2

        metadata.font = Self.metadataFont
        metadata.textColor = UIColor(resource: .homeSecondaryText)
        metadata.lineBreakMode = .byTruncatingTail
        metadata.numberOfLines = 1
    }

    private func makeHierarchy() {
        contentView.addSubview(card)
        card.addSubview(imageBox)
        imageBox.addSubview(imageView)
        imageBox.addSubview(placeholder)
        card.addSubview(name)
        card.addSubview(metadata)
    }

    private func makeLayout() {
        card.translatesAutoresizingMaskIntoConstraints = false
        imageBox.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        name.translatesAutoresizingMaskIntoConstraints = false
        metadata.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageBox.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            imageBox.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            imageBox.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
            imageBox.heightAnchor.constraint(equalTo: imageBox.widthAnchor),
            imageView.topAnchor.constraint(equalTo: imageBox.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageBox.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageBox.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageBox.bottomAnchor),
            placeholder.centerXAnchor.constraint(equalTo: imageBox.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: imageBox.centerYAnchor),
            placeholder.widthAnchor.constraint(equalToConstant: 24),
            placeholder.heightAnchor.constraint(equalToConstant: 20),
            name.topAnchor.constraint(equalTo: imageBox.bottomAnchor, constant: 10),
            name.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            name.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            metadata.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 10),
            metadata.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            metadata.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            metadata.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
    }

    private func bindTraitChanges() {
        updateBorder()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (cell: HomeImageCell, _) in
            cell.updateBorder()
        }
    }

    private func updateBorder() {
        card.layer.borderColor = UIColor(resource: .homeOutline).resolvedColor(with: traitCollection).cgColor
    }
}
