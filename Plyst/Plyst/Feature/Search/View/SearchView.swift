//
//  SearchView.swift
//  Plyst
//
//  Created by opfic on 9/30/26.
//

import UIKit

@MainActor
final class SearchView: UIView, SearchViewable {
    let layout = HomeGridLayout()
    private(set) lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private let fieldContainer = UIView()
    private let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
    private let searchField = UITextField()
    private let cancelButton = UIButton(type: .system)
    private let filterBar: HomeFilterBarView
    private let recentView: SearchRecentView
    private let emptyState = HomeEmptyStateView()
    private let toast = ToastView(textColor: UIColor(resource: .homeBottomText))
    private let send: @MainActor (SearchViewAction) -> Void

    init(
        frame: CGRect,
        send: @escaping @MainActor (SearchViewAction) -> Void
    ) {
        self.send = send
        filterBar = HomeFilterBarView { action in
            switch action {
            case .select(let filter): send(.selectFilter(filter))
            }
        }
        recentView = SearchRecentView { action in
            switch action {
            case .select(let term): send(.selectRecentTerm(term))
            case .remove(let term): send(.removeRecentTerm(term))
            case .clear: send(.clearRecentTerms)
            }
        }
        super.init(frame: frame)
        configureAppearance()
        registerCells()
        makeHierarchy()
        makeLayout()
        bindActions()
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

    var textCellType: any HomeTextCellable.Type { HomeTextCell.self }
    var imageCellType: any HomeImageCellable.Type { HomeImageCell.self }
    var sectionHeaderType: any HomeSectionHeaderViewable.Type { HomeSectionHeaderView.self }

    func focusSearchField() {
        searchField.becomeFirstResponder()
    }

    /// 상태의 검색어와 다를 때만 필드를 갱신해 입력 중인 커서와 조합 중인 글자를 보존합니다.
    func setQuery(_ query: String) {
        guard searchField.text != query else { return }
        searchField.text = query
    }

    func setSelectedFilter(_ filter: HomeFilter) {
        filterBar.setSelectedFilter(filter)
    }

    func reloadContent() {
        layout.invalidateLayout()
        collectionView.reloadData()
    }

    func scrollToTop() {
        collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.contentInset.top), animated: true)
    }

    /// 칩을 다시 만들기 때문에 최근 검색어 내용이 바뀔 때만 호출합니다.
    func setRecent(
        terms: [String],
        message: String?,
        showsClear: Bool
    ) {
        recentView.configure(terms: terms, message: message, showsClear: showsClear)
    }

    /// 검색어가 없을 때는 최근 검색어를, 있을 때는 결과 목록을 보여줍니다.
    func showRecent() {
        recentView.isHidden = false
        collectionView.isHidden = true
        emptyState.isHidden = true
    }

    func showResults() {
        recentView.isHidden = true
        collectionView.isHidden = false
        emptyState.isHidden = true
    }

    func showEmptyState(
        title: String,
        message: String
    ) {
        emptyState.configure(title: title, message: message)
        recentView.isHidden = true
        collectionView.isHidden = true
        emptyState.isHidden = false
    }

    func showFeedback(
        message: String,
        isSuccess: Bool
    ) {
        toast.show(
            message: message,
            backgroundColor: isSuccess
                ? UIColor(resource: .homeFeedbackSuccess)
                : UIColor(resource: .homeFeedbackFailure)
        )
    }

    func hideFeedback() {
        toast.hide()
    }

    private func configureAppearance() {
        backgroundColor = UIColor(resource: .homeCanvas)

        fieldContainer.backgroundColor = UIColor(resource: .homeCard)
        fieldContainer.layer.cornerRadius = 14
        fieldContainer.layer.borderWidth = 1.5

        searchIcon.tintColor = UIColor(resource: .homeSecondaryText)
        searchIcon.contentMode = .scaleAspectFit

        searchField.font = .systemFont(ofSize: 16)
        searchField.textColor = UIColor(resource: .homePrimaryText)
        searchField.placeholder = "복사한 내용 검색"
        searchField.returnKeyType = .search
        searchField.clearButtonMode = .whileEditing
        searchField.autocorrectionType = .no
        searchField.spellCheckingType = .no
        searchField.autocapitalizationType = .none

        cancelButton.setTitle("취소", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        cancelButton.setTitleColor(UIColor(resource: .homePrimaryText), for: .normal)

        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.contentInset.top = 8
        collectionView.contentInset.bottom = 16
        collectionView.isHidden = true

        recentView.isHidden = false
    }

    private func registerCells() {
        collectionView.register(textCellType, forCellWithReuseIdentifier: textCellType.reuseIdentifier)
        collectionView.register(imageCellType, forCellWithReuseIdentifier: imageCellType.reuseIdentifier)
        collectionView.register(
            sectionHeaderType,
            forSupplementaryViewOfKind: HomeGridLayout.headerKind,
            withReuseIdentifier: sectionHeaderType.reuseIdentifier
        )
    }

    private func makeHierarchy() {
        addSubview(fieldContainer)
        fieldContainer.addSubview(searchIcon)
        fieldContainer.addSubview(searchField)
        addSubview(cancelButton)
        addSubview(filterBar)
        addSubview(collectionView)
        addSubview(recentView)
        addSubview(emptyState)
        addSubview(toast)
    }

    private func makeLayout() {
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        filterBar.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        recentView.translatesAutoresizingMaskIntoConstraints = false
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        toast.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            fieldContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            fieldContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            fieldContainer.heightAnchor.constraint(equalToConstant: 46),
            cancelButton.leadingAnchor.constraint(equalTo: fieldContainer.trailingAnchor, constant: 12),
            cancelButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            cancelButton.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            searchIcon.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor, constant: 14),
            searchIcon.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 18),
            searchIcon.heightAnchor.constraint(equalToConstant: 18),
            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor, constant: -12),
            searchField.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            searchField.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor),
            filterBar.topAnchor.constraint(equalTo: fieldContainer.bottomAnchor, constant: 12),
            filterBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            filterBar.heightAnchor.constraint(equalToConstant: 40),
            collectionView.topAnchor.constraint(equalTo: filterBar.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
            recentView.topAnchor.constraint(equalTo: collectionView.topAnchor),
            recentView.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
            recentView.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
            recentView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
            emptyState.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyState.leadingAnchor.constraint(greaterThanOrEqualTo: collectionView.leadingAnchor, constant: 40),
            emptyState.trailingAnchor.constraint(lessThanOrEqualTo: collectionView.trailingAnchor, constant: -40),
            toast.centerXAnchor.constraint(equalTo: centerXAnchor),
            toast.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
    }

    private func bindActions() {
        searchField.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            send(.changeQuery(searchField.text ?? ""))
        }, for: .editingChanged)
        searchField.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            send(.submit)
            searchField.resignFirstResponder()
        }, for: .editingDidEndOnExit)
        cancelButton.addAction(UIAction { [weak self] _ in
            self?.send(.cancel)
        }, for: .touchUpInside)
    }

    private func bindTraitChanges() {
        updateBorder()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: SearchView, _) in
            view.updateBorder()
        }
    }

    private func updateBorder() {
        fieldContainer.layer.borderColor = UIColor(resource: .homeOutline).resolvedColor(with: traitCollection).cgColor
    }
}
