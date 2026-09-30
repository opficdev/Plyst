//
//  HomeView.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import UIKit

@MainActor
protocol HomeViewDelegate: AnyObject {
    func homeViewDidRequestSave(_ view: HomeView)
}

@MainActor
final class HomeView: UIView {
    weak var delegate: HomeViewDelegate?

    let layout = HomeGridLayout()
    private(set) lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private let titleHeader = HomeTitleHeaderView(frame: .zero)
    private let contentStack = UIStackView()
    private let emptyState = UIStackView()
    private let emptyTitle = UILabel()
    private let emptyBody = UILabel()
    private let saveBar = UIView()
    private let saveButton = UIButton(type: .system)
    private let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
    private let privacy = UILabel()
    private lazy var privacyRow = UIStackView(arrangedSubviews: [lock, privacy])
    private let feedbackView = UIView()
    private let feedbackLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        registerCells()
        makeHierarchy()
        makeLayout()
        bindActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func setSaving(_ isSaving: Bool) {
        saveButton.isEnabled = !isSaving
        saveButton.alpha = isSaving ? 0.55 : 1
    }

    func showEmptyState(
        title: String,
        message: String
    ) {
        emptyTitle.text = title
        emptyBody.text = message
        emptyState.isHidden = false
    }

    func hideEmptyState() {
        emptyState.isHidden = true
    }

    func showFeedback(
        message: String,
        isSuccess: Bool
    ) {
        feedbackLabel.text = message
        feedbackView.backgroundColor = isSuccess
            ? UIColor(resource: .homeFeedbackSuccess)
            : UIColor(resource: .homeFeedbackFailure)
        feedbackView.isHidden = false
    }

    func hideFeedback() {
        feedbackView.isHidden = true
    }

    private func configureAppearance() {
        backgroundColor = UIColor(resource: .homeCanvas)

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.distribution = .fill

        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false

        emptyState.axis = .vertical
        emptyState.alignment = .center
        emptyState.spacing = 10
        emptyState.isHidden = true

        emptyTitle.font = .systemFont(ofSize: 21, weight: .bold)
        emptyTitle.textColor = UIColor(resource: .homePrimaryText)
        emptyTitle.textAlignment = .center
        emptyTitle.numberOfLines = 0
        emptyBody.font = .systemFont(ofSize: 15)
        emptyBody.textColor = UIColor(resource: .homeSecondaryText)
        emptyBody.textAlignment = .center
        emptyBody.numberOfLines = 0

        saveBar.backgroundColor = UIColor(resource: .homeBottomBar)
        saveBar.layer.cornerRadius = 22
        saveBar.layer.shadowColor = UIColor(resource: .homeShadow).cgColor
        saveBar.layer.shadowOpacity = 0.18
        saveBar.layer.shadowRadius = 15
        saveBar.layer.shadowOffset = CGSize(width: 0, height: 8)

        var configuration = UIButton.Configuration.plain()
        configuration.title = "현재 클립보드 저장"
        configuration.image = UIImage(systemName: "doc.badge.plus")
        configuration.imagePadding = 9
        configuration.baseForegroundColor = UIColor(resource: .homeBottomText)
        saveButton.configuration = configuration
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.backgroundColor = UIColor(resource: .homeOnDark).withAlphaComponent(0.1)
        saveButton.layer.cornerRadius = 17

        lock.tintColor = UIColor(resource: .homeBottomText).withAlphaComponent(0.72)
        lock.contentMode = .scaleAspectFit
        privacy.text = "이 기기에만 저장됩니다"
        privacy.font = .systemFont(ofSize: 12)
        privacy.textColor = UIColor(resource: .homeBottomText).withAlphaComponent(0.72)
        privacyRow.axis = .horizontal
        privacyRow.alignment = .center
        privacyRow.spacing = 6

        feedbackView.backgroundColor = UIColor(resource: .homeFeedbackSuccess)
        feedbackView.layer.cornerRadius = 12
        feedbackView.isHidden = true
        feedbackLabel.font = .systemFont(ofSize: 14, weight: .medium)
        feedbackLabel.textColor = UIColor(resource: .homeOnDark)
        feedbackLabel.textAlignment = .center
        feedbackLabel.numberOfLines = 0
    }

    private func registerCells() {
        collectionView.register(HomeTextCell.self, forCellWithReuseIdentifier: HomeTextCell.reuseIdentifier)
        collectionView.register(HomeImageCell.self, forCellWithReuseIdentifier: HomeImageCell.reuseIdentifier)
        collectionView.register(
            HomeSectionHeaderView.self,
            forSupplementaryViewOfKind: HomeGridLayout.headerKind,
            withReuseIdentifier: HomeSectionHeaderView.reuseIdentifier
        )
    }

    private func makeHierarchy() {
        addSubview(contentStack)
        contentStack.addArrangedSubview(titleHeader)
        contentStack.addArrangedSubview(collectionView)
        addSubview(emptyState)
        emptyState.addArrangedSubview(emptyTitle)
        emptyState.addArrangedSubview(emptyBody)
        addSubview(saveBar)
        saveBar.addSubview(saveButton)
        saveBar.addSubview(privacyRow)
        addSubview(feedbackView)
        feedbackView.addSubview(feedbackLabel)
    }

    private func makeLayout() {
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        titleHeader.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        saveBar.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        lock.translatesAutoresizingMaskIntoConstraints = false
        privacyRow.translatesAutoresizingMaskIntoConstraints = false
        feedbackView.translatesAutoresizingMaskIntoConstraints = false
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: saveBar.topAnchor, constant: -12),
            titleHeader.heightAnchor.constraint(equalToConstant: 68),
            saveBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            saveBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            saveBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            saveButton.topAnchor.constraint(equalTo: saveBar.topAnchor, constant: 6),
            saveButton.leadingAnchor.constraint(equalTo: saveBar.leadingAnchor, constant: 6),
            saveButton.trailingAnchor.constraint(equalTo: saveBar.trailingAnchor, constant: -6),
            saveButton.heightAnchor.constraint(equalToConstant: 54),
            privacyRow.topAnchor.constraint(equalTo: saveButton.bottomAnchor),
            privacyRow.centerXAnchor.constraint(equalTo: saveBar.centerXAnchor),
            privacyRow.heightAnchor.constraint(equalToConstant: 30),
            privacyRow.bottomAnchor.constraint(equalTo: saveBar.bottomAnchor),
            lock.widthAnchor.constraint(equalToConstant: 10),
            lock.heightAnchor.constraint(equalToConstant: 12),
            emptyState.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor, constant: 24),
            emptyState.leadingAnchor.constraint(greaterThanOrEqualTo: collectionView.leadingAnchor, constant: 40),
            emptyState.trailingAnchor.constraint(lessThanOrEqualTo: collectionView.trailingAnchor, constant: -40),
            feedbackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            feedbackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            feedbackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            feedbackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            feedbackLabel.topAnchor.constraint(equalTo: feedbackView.topAnchor, constant: 11),
            feedbackLabel.bottomAnchor.constraint(equalTo: feedbackView.bottomAnchor, constant: -11),
            feedbackLabel.leadingAnchor.constraint(equalTo: feedbackView.leadingAnchor, constant: 14),
            feedbackLabel.trailingAnchor.constraint(equalTo: feedbackView.trailingAnchor, constant: -14)
        ])
    }

    private func bindActions() {
        saveButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            delegate?.homeViewDidRequestSave(self)
        }, for: .touchUpInside)
    }

}
